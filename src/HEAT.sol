// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.35;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {OFTUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTUpgradeable.sol";

/// @title HEAT
/// @notice ERC-20 token for the Hibachi protocol.
contract HEAT is
    Initializable,
    OFTUpgradeable,
    ERC20PermitUpgradeable,
    ERC20BurnableUpgradeable,
    AccessControlUpgradeable
{
    error AddressIsZero();
    error EnforcedGlobalFreeze();
    error EnforcedAccountFreeze(address account);

    /// @notice Emitted when the token is globally frozen.
    event GlobalFrozen();

    /// @notice Emitted when the token is globally unfrozen.
    event GlobalUnfrozen();

    /// @notice Emitted when an account is frozen.
    /// @param account The account that has been frozen.
    event AccountFrozen(address indexed account);

    /// @notice Emitted when an account is unfrozen.
    /// @param account The account that has been frozen.
    event AccountUnfrozen(address indexed account);

    /// @custom:storage-location erc7201:hibachi.storage.HEAT
    struct HeatStorage {
        bool _globalFrozen;
        mapping(address account => bool) _frozen;
    }

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant FREEZE_ROLE = keccak256("FREEZE_ROLE");

    // keccak256(abi.encode(uint256(keccak256("hibachi.storage.HEAT")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant HEAT_STORAGE_LOCATION = 0xac15fc679ca03392ee67e2babf286038a2db88c0a3e79bd1fd073d7725dea600;

    function _getHeatStorage() private pure returns (HeatStorage storage $) {
        assembly {
            $.slot := HEAT_STORAGE_LOCATION
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _lzEndpoint) OFTUpgradeable(_lzEndpoint) {
        _disableInitializers();
    }

    /// @notice Initializes the contract.
    /// @param initialAdmin The address that will become the default admin and owner.
    /// @param initialRecipient The address of the recipient of the initial token supply.
    /// @param initialSupply The initial token supply.
    function initialize(address initialAdmin, address initialRecipient, uint256 initialSupply) external initializer {
        require(initialAdmin != address(0), AddressIsZero());
        if (initialSupply > 0) {
            require(initialRecipient != address(0), AddressIsZero());
        }

        // OFTAppCoreUpgradeable inherits from OwnableUpgradeable but does not set an owner
        __Ownable_init(initialAdmin);
        __OFT_init("HEAT", "HEAT", initialAdmin);
        __ERC20Permit_init("HEAT");
        __ERC20Burnable_init();
        __AccessControl_init();

        // ACL definitions
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);

        // mint initial supply
        if (initialSupply > 0) {
            _mint(initialRecipient, initialSupply);
        }
    }

    /// @notice Transfers LayerZero ownership and delegate.
    /// @param newOwner The address of the new owner.
    function transferOwnership(address newOwner) public override onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        setDelegate(newOwner);
        _transferOwnership(newOwner);
    }

    /// @notice Mints tokens. Requires MINTER_ROLE.
    /// @param to The address to receive the minted tokens.
    /// @param amount The amount of tokens to mint.
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /// @notice Freezes / unfreezes the token globally. Requires FREEZE_ROLE.
    /// @param frozen Whether the token should be globally frozen.
    function setGlobalFrozen(bool frozen) external onlyRole(FREEZE_ROLE) {
        HeatStorage storage $ = _getHeatStorage();
        if ($._globalFrozen == frozen) return;

        $._globalFrozen = frozen;
        if (frozen) emit GlobalFrozen();
        else emit GlobalUnfrozen();
    }

    /// @notice Freezes / unfreezes a specific account. Requires FREEZE_ROLE.
    /// @param account The account to freeze / unfreeze.
    /// @param frozen Whether the token should be globally frozen.
    function setFrozen(address account, bool frozen) external onlyRole(FREEZE_ROLE) {
        HeatStorage storage $ = _getHeatStorage();

        if ($._frozen[account] == frozen) return;

        $._frozen[account] = frozen;
        if (frozen) emit AccountFrozen(account);
        else emit AccountUnfrozen(account);
    }

    /// @notice Retrieves whether the token is globally frozen.
    /// @return globalFrozen Whether the token is globally frozen.
    function isGlobalFrozen() external view returns (bool) {
        HeatStorage storage $ = _getHeatStorage();

        return $._globalFrozen;
    }

    /// @notice Retrieves whether the token is frozen for an account.
    /// @param account The account.
    /// @return globalFrozen Whether the token is frozen for an account.
    function isFrozen(address account) public view returns (bool) {
        HeatStorage storage $ = _getHeatStorage();
        return $._globalFrozen || $._frozen[account];
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        HeatStorage storage $ = _getHeatStorage();

        if ($._globalFrozen) revert EnforcedGlobalFreeze();

        if (from != address(0) && $._frozen[from]) revert EnforcedAccountFreeze(from);
        if (to != address(0) && $._frozen[to]) revert EnforcedAccountFreeze(to);

        super._update(from, to, value);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual override {
        HeatStorage storage $ = _getHeatStorage();

        if ($._globalFrozen) revert EnforcedGlobalFreeze();

        if ($._frozen[owner]) revert EnforcedAccountFreeze(owner);
        if ($._frozen[spender]) revert EnforcedAccountFreeze(spender);

        super._approve(owner, spender, value, emitEvent);
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual override {
        HeatStorage storage $ = _getHeatStorage();

        if ($._globalFrozen) revert EnforcedGlobalFreeze();

        if ($._frozen[owner]) revert EnforcedAccountFreeze(owner);
        if ($._frozen[spender]) revert EnforcedAccountFreeze(spender);

        super._spendAllowance(owner, spender, value);
    }
}
