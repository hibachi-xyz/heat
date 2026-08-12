// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {HEAT} from "../src/HEAT.sol";

contract HEATTest is TestHelperOz5 {
    // re-declaration of the typehash, this is private in the OZ implementation
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    HEAT public heatAImpl;
    HEAT public heatA;

    address public defaultAdmin;
    uint256 public defaultAdminKey;

    address public initialSupplyHolder;
    uint256 public initialSupplyHolderKey;

    address public minter;
    uint256 public minterKey;

    function setUp() public override {
        super.setUp();

        setUpEndpoints(2, LibraryType.UltraLightNode);

        (defaultAdmin, defaultAdminKey) = makeAddrAndKey("defaultAdmin");
        (initialSupplyHolder, initialSupplyHolderKey) = makeAddrAndKey("initialSupplyHolder");
        (minter, minterKey) = makeAddrAndKey("minter");

        heatAImpl = new HEAT(endpoints[1]);
        bytes memory heatAInitData = abi.encodeCall(HEAT.initialize, (defaultAdmin, initialSupplyHolder, 1_000));
        heatA = HEAT(address(new ERC1967Proxy(address(heatAImpl), heatAInitData)));

        bytes32 minterRole = heatA.MINTER_ROLE();

        vm.prank(defaultAdmin);
        heatA.grantRole(minterRole, minter);
    }

    function test_CannotInitializeImplementation() public {
        vm.expectRevert();
        heatAImpl.initialize(address(this), address(this), 1);
    }

    function test_IsCorrectlyInitialized() public view {
        assertEq(address(heatA.endpoint()), endpoints[1]);
        assertEq(heatA.owner(), defaultAdmin);
        assertEq(heatA.balanceOf(address(this)), 0);
        assertEq(heatA.balanceOf(initialSupplyHolder), 1_000);
        assertEq(heatA.totalSupply(), 1_000);
        assertEq(heatA.name(), "HEAT");
        assertEq(heatA.symbol(), "HEAT");
        assertEq(heatA.decimals(), 18);
        assertEq(heatA.sharedDecimals(), 6);
    }

    function test_CanMint() public {
        assert(heatA.hasRole(heatA.MINTER_ROLE(), minter));

        vm.expectRevert();
        heatA.mint(initialSupplyHolder, 500);

        vm.prank(minter);
        heatA.mint(defaultAdmin, 600);

        assertEq(heatA.balanceOf(defaultAdmin), 600);
        assertEq(heatA.totalSupply(), 1_600);
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
}
