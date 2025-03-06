// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../LibVincentDiamondStorage.sol";
import "../VincentBase.sol";

interface IVincentToolFacet {
    function registerTool(string calldata toolIpfsCid) external;
}

contract VincentAppFacet is VincentBase {
    using VincentAppStorage for VincentAppStorage.AppStorage;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    event NewManagerRegistered(address indexed manager);
    event NewAppRegistered(uint256 indexed appId, address indexed manager);
    event AppEnabled(uint256 indexed appId, bool indexed enabled);
    event AuthorizedDomainAdded(uint256 indexed appId, string indexed domain);
    event AuthorizedRedirectUriAdded(uint256 indexed appId, string indexed redirectUri);
    event AuthorizedDomainRemoved(uint256 indexed appId, string indexed domain);
    event AuthorizedRedirectUriRemoved(uint256 indexed appId, string indexed redirectUri);

    error NotAppManager(uint256 appId, address msgSender);
    error DelegateeAlreadyRegisteredToApp(address delegatee, uint256 appId);
    error DelegateeNotRegisteredToApp(address delegatee, uint256 appId);
    error AuthorizedDomainNotRegistered(uint256 appId, bytes32 hashedDomain);
    error AuthorizedRedirectUriNotRegistered(uint256 appId, bytes32 hashedRedirectUri);

    modifier onlyAppManager(uint256 appId) {
        VincentAppStorage.AppStorage storage as_ = VincentAppStorage.appStorage();
        if (as_.appIdToApp[appId].manager != msg.sender) revert NotAppManager(appId, msg.sender);
        _;
    }

    function registerApp(
        string calldata name,
        string calldata description,
        string[] calldata authorizedDomains,
        string[] calldata authorizedRedirectUris,
        string[] calldata toolIpfsCids,
        address[] calldata delegatees
    ) public returns (uint256 newAppId) {
        VincentAppStorage.AppStorage storage as_ = VincentAppStorage.appStorage();

        newAppId = _registerApp(name, description, authorizedDomains, authorizedRedirectUris, toolIpfsCids, delegatees);

        // Add the manager to the list of registered managers
        // if they are not already in the list
        if (!as_.registeredManagers.contains(msg.sender)) {
            as_.registeredManagers.add(msg.sender);
            emit NewManagerRegistered(msg.sender);
        }

        emit NewAppRegistered(newAppId, msg.sender);
    }

    function enableApp(uint256 appId, bool enabled) external onlyAppManager(appId) onlyRegisteredApp(appId) {
        VincentAppStorage.AppStorage storage as_ = VincentAppStorage.appStorage();
        as_.appIdToApp[appId].enabled = enabled;
        emit AppEnabled(appId, enabled);
    }

    function addAuthorizedDomain(uint256 appId, string calldata domain)
        external
        onlyAppManager(appId)
        onlyRegisteredApp(appId)
    {
        _addAuthorizedDomain(appId, domain);
    }

    function removeAuthorizedDomain(uint256 appId, string calldata domain)
        external
        onlyAppManager(appId)
        onlyRegisteredApp(appId)
    {
        VincentAppStorage.AppStorage storage as_ = VincentAppStorage.appStorage();

        bytes32 hashedDomain = keccak256(abi.encodePacked(domain));

        if (!as_.appIdToApp[appId].authorizedDomains.contains(hashedDomain)) {
            revert AuthorizedDomainNotRegistered(appId, hashedDomain);
        }

        as_.appIdToApp[appId].authorizedDomains.remove(hashedDomain);
        delete as_.authorizedDomainHashToDomain[hashedDomain];

        emit AuthorizedDomainRemoved(appId, domain);
    }

    function addAuthorizedRedirectUri(uint256 appId, string calldata redirectUri)
        external
        onlyAppManager(appId)
        onlyRegisteredApp(appId)
    {
        _addAuthorizedRedirectUri(appId, redirectUri);
    }

    function removeAuthorizedRedirectUri(uint256 appId, string calldata redirectUri)
        external
        onlyAppManager(appId)
        onlyRegisteredApp(appId)
    {
        VincentAppStorage.AppStorage storage as_ = VincentAppStorage.appStorage();

        bytes32 hashedRedirectUri = keccak256(abi.encodePacked(redirectUri));

        if (!as_.appIdToApp[appId].authorizedRedirectUris.contains(hashedRedirectUri)) {
            revert AuthorizedRedirectUriNotRegistered(appId, hashedRedirectUri);
        }

        as_.appIdToApp[appId].authorizedRedirectUris.remove(hashedRedirectUri);
        delete as_.authorizedRedirectUriHashToRedirectUri[hashedRedirectUri];

        emit AuthorizedRedirectUriRemoved(appId, redirectUri);
    }

    function addDelegatee(uint256 appId, address delegatee) external onlyAppManager(appId) onlyRegisteredApp(appId) {
        VincentAppStorage.AppStorage storage as_ = VincentAppStorage.appStorage();

        uint256 delegateeAppId = as_.delegateeAddressToAppId[delegatee];
        if (delegateeAppId != 0) revert DelegateeAlreadyRegisteredToApp(delegatee, delegateeAppId);

        as_.appIdToApp[appId].delegatees.add(delegatee);
        as_.delegateeAddressToAppId[delegatee] = appId;
    }

    function removeDelegatee(uint256 appId, address delegatee)
        external
        onlyAppManager(appId)
        onlyRegisteredApp(appId)
    {
        VincentAppStorage.AppStorage storage as_ = VincentAppStorage.appStorage();

        if (as_.delegateeAddressToAppId[delegatee] != appId) revert DelegateeNotRegisteredToApp(delegatee, appId);

        as_.appIdToApp[appId].delegatees.remove(delegatee);
        as_.delegateeAddressToAppId[delegatee] = 0;
    }

    function _registerApp(
        string calldata name,
        string calldata description,
        string[] calldata authorizedDomains,
        string[] calldata authorizedRedirectUris,
        string[] calldata toolIpfsCids,
        address[] calldata delegatees
    ) internal returns (uint256 newAppId) {
        VincentAppStorage.AppStorage storage as_ = VincentAppStorage.appStorage();

        newAppId = as_.appIdCounter++;

        // Add the app to the list of registered apps
        as_.registeredApps.add(newAppId);

        // Add the app to the manager's list of apps
        as_.managerAddressToAppIds[msg.sender].add(newAppId);

        // Register the app
        VincentAppStorage.App storage app = as_.appIdToApp[newAppId];
        app.manager = msg.sender;
        app.enabled = true;
        app.name = name;
        app.description = description;

        for (uint256 i = 0; i < authorizedDomains.length; i++) {
            _addAuthorizedDomain(newAppId, authorizedDomains[i]);
        }

        for (uint256 i = 0; i < authorizedRedirectUris.length; i++) {
            _addAuthorizedRedirectUri(newAppId, authorizedRedirectUris[i]);
        }

        // Add the delegatees to the app
        for (uint256 i = 0; i < delegatees.length; i++) {
            app.delegatees.add(delegatees[i]);
            as_.delegateeAddressToAppId[delegatees[i]] = newAppId;
        }

        // Register the tools and add to the app
        for (uint256 i = 0; i < toolIpfsCids.length; i++) {
            bytes32 hashedIpfsCid = keccak256(abi.encodePacked(toolIpfsCids[i]));

            if (!app.toolIpfsCidHashes.contains(hashedIpfsCid)) {
                app.toolIpfsCidHashes.add(hashedIpfsCid);

                IVincentToolFacet(address(this)).registerTool(toolIpfsCids[i]);
            }
        }
    }

    function _addAuthorizedDomain(uint256 appId, string calldata domain) internal {
        VincentAppStorage.AppStorage storage as_ = VincentAppStorage.appStorage();

        bytes32 hashedDomain = keccak256(abi.encodePacked(domain));

        as_.appIdToApp[appId].authorizedDomains.add(hashedDomain);
        as_.authorizedDomainHashToDomain[hashedDomain] = domain;

        emit AuthorizedDomainAdded(appId, domain);
    }

    function _addAuthorizedRedirectUri(uint256 appId, string calldata redirectUri) internal {
        VincentAppStorage.AppStorage storage as_ = VincentAppStorage.appStorage();

        bytes32 hashedRedirectUri = keccak256(abi.encodePacked(redirectUri));

        as_.appIdToApp[appId].authorizedRedirectUris.add(hashedRedirectUri);
        as_.authorizedRedirectUriHashToRedirectUri[hashedRedirectUri] = redirectUri;

        emit AuthorizedRedirectUriAdded(appId, redirectUri);
    }
}
