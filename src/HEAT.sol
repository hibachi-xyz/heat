// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {OFTUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTUpgradeable.sol";

contract HEAT is Initializable, OFTUpgradeable, ERC20PermitUpgradeable, AccessControlUpgradeable {
    error EnforcedGlobalFreeze();
    error EnforcedAccountFreeze(address account);

    event GlobalFreezeSet(bool frozen);
    event AccountFrozen(address indexed account);
    event AccountUnfrozen(address indexed account);

    /// @custom:storage-location erc7201:hibachi.storage.HEAT
    struct HEATStorage {
        bool _globalFrozen;
        mapping(address account => bool) _frozen;
    }

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant FREEZE_ROLE = keccak256("FREEZE_ROLE");

    // keccak256(abi.encode(uint256(keccak256("hibachi.storage.HEAT")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant HEAT_STORAGE_LOCATION = 0xac15fc679ca03392ee67e2babf286038a2db88c0a3e79bd1fd073d7725dea600;

    function _getHEATStorage() private pure returns (HEATStorage storage $) {
        assembly {
            $.slot := HEAT_STORAGE_LOCATION
        }
    }

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

    function setGlobalFrozen(bool frozen) external onlyRole(FREEZE_ROLE) {
        HEATStorage storage $ = _getHEATStorage();
        if ($._globalFrozen == frozen) return;

        $._globalFrozen = frozen;
        emit GlobalFreezeSet(frozen);
    }

    function setFrozen(address account, bool frozen) external onlyRole(FREEZE_ROLE) {
        HEATStorage storage $ = _getHEATStorage();

        bool prev = $._frozen[account];
        if (prev == frozen) return;

        $._frozen[account] = frozen;
        if (frozen) emit AccountFrozen(account);
        else emit AccountUnfrozen(account);
    }

    function isFrozen(address account) public view returns (bool) {
        HEATStorage storage $ = _getHEATStorage();
        return $._globalFrozen || $._frozen[account];
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        HEATStorage storage $ = _getHEATStorage();

        if ($._globalFrozen) revert EnforcedGlobalFreeze();

        if (from != address(0) && $._frozen[from]) revert EnforcedAccountFreeze(from);
        if (to != address(0) && $._frozen[to]) revert EnforcedAccountFreeze(to);

        super._update(from, to, value);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual override {
        HEATStorage storage $ = _getHEATStorage();

        if ($._globalFrozen) revert EnforcedGlobalFreeze();

        if ($._frozen[owner]) revert EnforcedAccountFreeze(owner);
        if ($._frozen[spender]) revert EnforcedAccountFreeze(spender);

        super._approve(owner, spender, value, emitEvent);
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual override {
        HEATStorage storage $ = _getHEATStorage();

        if ($._globalFrozen) revert EnforcedGlobalFreeze();

        if ($._frozen[owner]) revert EnforcedAccountFreeze(owner);
        if ($._frozen[spender]) revert EnforcedAccountFreeze(spender);

        super._spendAllowance(owner, spender, value);
    }
}
