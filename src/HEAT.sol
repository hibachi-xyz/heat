// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {OFTUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTUpgradeable.sol";

contract HEAT is Initializable, OFTUpgradeable, ERC20PermitUpgradeable, AccessControlUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _lzEndpoint) OFTUpgradeable(_lzEndpoint) {
        _disableInitializers();
    }

    function initialize(address initialAdmin, address initialRecipient, uint256 initialSupply) external initializer {
        // OFTAppCoreUpgradeable inherits from OwnableUpgradeable but does not set an owner
        __Ownable_init(initialAdmin);
        __OFT_init("HEAT", "HEAT", initialAdmin);
        __ERC20Permit_init("HEAT");
        __AccessControl_init();

        // ACL definitions
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);

        // mint initial supply
        _mint(initialRecipient, initialSupply);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
