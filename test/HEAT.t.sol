// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {SendParam, MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppOptionsType3.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {HEAT} from "../src/HEAT.sol";

contract HEATTest is TestHelperOz5 {
    // re-declaration of the typehash, this is private in the OZ implementation
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    HEAT public heatAImpl;
    HEAT public heatA;
    HEAT public heatB;

    address public defaultAdmin;
    uint256 public defaultAdminKey;

    address public initialSupplyHolder;
    uint256 public initialSupplyHolderKey;

    address public minter;
    uint256 public minterKey;

    address public freezer;

    using OptionsBuilder for bytes;

    function setUp() public override {
        super.setUp();

        setUpEndpoints(2, LibraryType.UltraLightNode);

        (defaultAdmin, defaultAdminKey) = makeAddrAndKey("defaultAdmin");
        (initialSupplyHolder, initialSupplyHolderKey) = makeAddrAndKey("initialSupplyHolder");
        (minter, minterKey) = makeAddrAndKey("minter");
        freezer = makeAddr("freezer");

        heatAImpl = new HEAT(endpoints[1]);
        bytes memory _heatAInitData = abi.encodeCall(HEAT.initialize, (defaultAdmin, initialSupplyHolder, 10 ** 18));
        heatA = HEAT(address(new ERC1967Proxy(address(heatAImpl), _heatAInitData)));

        heatB = new HEAT(endpoints[2]);
        bytes memory _heatBInitData = abi.encodeCall(HEAT.initialize, (defaultAdmin, initialSupplyHolder, 2 * 10 ** 18));
        heatB = HEAT(address(new ERC1967Proxy(address(heatB), _heatBInitData)));

        bytes32 minterRole = heatA.MINTER_ROLE();
        bytes32 freezeRole = heatA.FREEZE_ROLE();

        vm.prank(defaultAdmin);
        heatA.grantRole(minterRole, minter);

        vm.prank(defaultAdmin);
        heatA.grantRole(freezeRole, freezer);

        // LayerZero peer setup
        vm.prank(defaultAdmin);
        heatA.setPeer(2, bytes32(uint256(uint160(address(heatB)))));
        vm.prank(defaultAdmin);
        heatB.setPeer(1, bytes32(uint256(uint160(address(heatA)))));
    }

    function test_CannotInitializeImplementation() public {
        vm.expectRevert();
        heatAImpl.initialize(address(this), address(this), 1);
    }

    function test_IsCorrectlyInitialized() public view {
        assertEq(address(heatA.endpoint()), endpoints[1]);
        assertEq(heatA.owner(), defaultAdmin);
        assertEq(heatA.balanceOf(address(this)), 0);
        assertEq(heatA.balanceOf(initialSupplyHolder), 10 ** 18);
        assertEq(heatA.totalSupply(), 10 ** 18);
        assertEq(heatA.name(), "HEAT");
        assertEq(heatA.symbol(), "HEAT");
        assertEq(heatA.decimals(), 18);
        assertEq(heatA.sharedDecimals(), 6);
    }

    function test_CanBurn() public {
        vm.prank(initialSupplyHolder);
        heatA.burn(10 ** 17);

        assertEq(heatA.balanceOf(initialSupplyHolder), 9 * 10 ** 17);
        assertEq(heatA.totalSupply(), 9 * 10 ** 17);
    }

    function test_CanMint() public {
        assert(heatA.hasRole(heatA.MINTER_ROLE(), minter));

        vm.expectRevert();
        heatA.mint(initialSupplyHolder, 500);

        vm.prank(minter);
        heatA.mint(defaultAdmin, 600);

        assertEq(heatA.balanceOf(defaultAdmin), 600);
        assertEq(heatA.totalSupply(), 10 ** 18 + 600);
    }

    function test_PermitSetsAllowanceAndIncrementsNonce() public {
        address spender = makeAddr("spender");
        address relayer = makeAddr("relayer");

        assertEq(heatA.allowance(initialSupplyHolder, spender), 0);

        uint256 nonce = heatA.nonces(initialSupplyHolder);
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, initialSupplyHolder, spender, 100, nonce, deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", heatA.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(initialSupplyHolderKey, digest);

        vm.expectEmit(true, true, false, true, address(heatA));
        emit IERC20.Approval(initialSupplyHolder, spender, 100);

        vm.prank(relayer);
        heatA.permit(initialSupplyHolder, spender, 100, deadline, v, r, s);

        assertEq(heatA.allowance(initialSupplyHolder, spender), 100);
        assertEq(heatA.nonces(initialSupplyHolder), nonce + 1);
    }

    function test_GlobalFreezeWorks() public {
        address recipient = makeAddr("recipient");

        vm.prank(initialSupplyHolder);
        assert(heatA.transfer(recipient, 100));

        assert(!heatA.isGlobalFrozen());

        vm.prank(freezer);
        heatA.setGlobalFrozen(true);

        assert(heatA.isGlobalFrozen());

        vm.prank(initialSupplyHolder);
        vm.expectRevert();
        assert(!heatA.transfer(recipient, 100));
    }

    function test_AccountFreezeWorks() public {
        address recipient = makeAddr("recipient");

        vm.prank(initialSupplyHolder);
        assert(heatA.transfer(recipient, 100));

        assert(!heatA.isFrozen(recipient));

        vm.prank(freezer);
        heatA.setFrozen(recipient, true);

        assert(heatA.isFrozen(recipient));

        vm.prank(initialSupplyHolder);
        vm.expectRevert();
        assert(!heatA.transfer(recipient, 100));
    }

    function test_OFTTransferWorks() public {
        EnforcedOptionParam[] memory params = new EnforcedOptionParam[](1);
        params[0] = EnforcedOptionParam({
            eid: 2, msgType: 1, options: OptionsBuilder.newOptions().addExecutorLzReceiveOption(80_000, 0)
        });

        vm.prank(defaultAdmin);
        heatA.setEnforcedOptions(params);

        address recipient = makeAddr("recipientB");
        address refundRecipient = makeAddr("refund");

        SendParam memory _sendParam = SendParam({
            dstEid: 2,
            to: bytes32(uint256(uint160(recipient))),
            amountLD: 10 ** 17, // 0.1 HEAT
            minAmountLD: 10 ** 17, // 0.1 HEAT
            extraOptions: hex"",
            composeMsg: hex"",
            oftCmd: hex""
        });

        MessagingFee memory _quotedFees = heatA.quoteSend(_sendParam, false);

        assertEq(heatA.totalSupply(), 10 ** 18);
        assertEq(heatB.totalSupply(), 2 * 10 ** 18);

        uint256 _nativeBalanceToDeal = _quotedFees.nativeFee + 1_000_000_000;

        vm.deal(initialSupplyHolder, _nativeBalanceToDeal);
        assertEq(initialSupplyHolder.balance, _nativeBalanceToDeal);

        MessagingFee memory _sentFees = MessagingFee({nativeFee: _quotedFees.nativeFee + 1_000, lzTokenFee: 0});

        vm.prank(initialSupplyHolder);
        heatA.send{value: _sentFees.nativeFee}(_sendParam, _sentFees, refundRecipient);

        assertEq(refundRecipient.balance, 1_000);

        // token has been burnt on the source chain but not the destination chain
        assertEq(heatA.totalSupply(), 10 ** 18 - 10 ** 17);
        assertEq(heatB.totalSupply(), 2 * 10 ** 18);

        verifyPackets(2, bytes32(uint256(uint160(address(heatB)))));

        // token has been relayed, summed up supply stays constant
        assertEq(heatA.totalSupply(), 10 ** 18 - 10 ** 17);
        assertEq(heatB.totalSupply(), 2 * 10 ** 18 + 10 ** 17);
    }
}
