use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp,
    stop_cheat_block_timestamp,
};
use ip_collective_agreement::types::{IPAssetType};
use ip_collective_agreement::interface::{
    IOwnershipRegistryDispatcher, IOwnershipRegistryDispatcherTrait, IIPAssetManagerDispatcher,
    IIPAssetManagerDispatcherTrait, IRevenueDistributionDispatcher,
    IRevenueDistributionDispatcherTrait,
};
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use core::num::traits::Bounded;

use super::test_utils::{
    OWNER, CREATOR1, CREATOR2, CREATOR3, USER, SPENDER, MARKETPLACE, setup,
    create_test_creators_data, register_test_asset, deploy_erc1155_receiver,
};


#[test]
fn test_register_ip_asset_success() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();

    let asset_type = IPAssetType::Art.into();
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);

    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri.clone(), creators, ownership_percentages, governance_weights,
        );

    stop_cheat_caller_address(contract_address);

    // Verify asset registration
    assert(asset_id == 1, 'Asset ID should be 1');

    let asset_info = asset_dispatcher.get_asset_info(asset_id);
    assert(asset_info.asset_id == asset_id, 'Wrong asset ID in info');
    assert(asset_info.asset_type == asset_type, 'Wrong asset type');
    assert(asset_info.metadata_uri == metadata_uri, 'Wrong metadata URI');
    assert(asset_info.total_supply == 1000, 'Wrong total supply');
    assert!(asset_info.is_verified == false, "Should not be verified initially");

    // Verify ownership registration
    let ownership_info = ownership_dispatcher.get_ownership_info(asset_id);
    assert(ownership_info.total_owners == 3, 'Wrong number of owners');
    assert(ownership_info.is_active == true, 'Ownership should be active');

    // Verify individual ownership percentages
    assert(
        ownership_dispatcher.get_owner_percentage(asset_id, creator1) == 50,
        'Wrong CREATOR1 percentage',
    );
    assert(
        ownership_dispatcher.get_owner_percentage(asset_id, creator2) == 30,
        'Wrong CREATOR2 percentage',
    );
    assert(
        ownership_dispatcher.get_owner_percentage(asset_id, creator3) == 20,
        'Wrong CREATOR3 percentage',
    );

    // Verify governance weights
    assert!(
        ownership_dispatcher.get_governance_weight(asset_id, creator1) == 40,
        "Wrong CREATOR1 governance weight",
    );
    assert!(
        ownership_dispatcher.get_governance_weight(asset_id, creator2) == 35,
        "Wrong CREATOR2 governance weight",
    );
    assert!(
        ownership_dispatcher.get_governance_weight(asset_id, creator3) == 25,
        "Wrong CREATOR3 governance weight",
    );
}

#[test]
fn test_erc1155_token_minting() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    let asset_type = 'MUSIC';
    let metadata_uri: ByteArray = "ipfs://QmMusicMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);

    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );

    stop_cheat_caller_address(contract_address);

    // Verify ERC1155 tokens were minted according to ownership percentages
    let creator1_balance = erc1155_dispatcher.balance_of(creator1, asset_id);
    let creator2_balance = erc1155_dispatcher.balance_of(creator2, asset_id);
    let creator3_balance = erc1155_dispatcher.balance_of(creator3, asset_id);

    assert(creator1_balance == 500, 'Wrong CREATOR1 token balance'); // 50% of 1000
    assert(creator2_balance == 300, 'Wrong CREATOR2 token balance'); // 30% of 1000
    assert(creator3_balance == 200, 'Wrong CREATOR3 token balance'); // 20% of 1000

    // Verify total supply
    assert(asset_dispatcher.get_total_supply(asset_id) == 1000, 'Wrong total supply');
}

#[test]
#[should_panic(expected: "Contract is paused")]
fn test_register_ip_asset_when_paused() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    let owner: ContractAddress = owner_address;
    start_cheat_caller_address(contract_address, owner);

    // Pause the contract
    asset_dispatcher.pause_contract();

    let asset_type = IPAssetType::Art.into();
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let user: ContractAddress = USER();

    asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
}

#[test]
#[should_panic(expected: "At least one creator required")]
fn test_register_ip_asset_no_creators() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    let asset_type = IPAssetType::Art.into();
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let empty_creators = array![].span();
    let empty_percentages = array![].span();
    let empty_weights = array![].span();

    start_cheat_caller_address(contract_address, OWNER());

    asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, empty_creators, empty_percentages, empty_weights,
        );
}

#[test]
#[should_panic(expected: "Creators and percentages length mismatch")]
fn test_register_ip_asset_mismatched_arrays() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    let asset_type = IPAssetType::Art.into();
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let creators = array![CREATOR1(), CREATOR2()].span();
    let ownership_percentages = array![100_u256].span(); // Mismatch: 2 creators, 1 percentage
    let governance_weights = array![100_u256, 0_u256].span();

    start_cheat_caller_address(contract_address, OWNER());

    asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
}

#[test]
#[should_panic(expected: "Total ownership must equal 100%")]
fn test_register_ip_asset_invalid_percentages() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    let asset_type = IPAssetType::Art.into();
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let creators = array![CREATOR1(), CREATOR2()].span();
    let ownership_percentages = array![60_u256, 30_u256].span();
    let governance_weights = array![50_u256, 50_u256].span();

    start_cheat_caller_address(contract_address, OWNER());

    asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
}

#[test]
fn test_ownership_transfer() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    let asset_type = IPAssetType::Art.into();
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );

    stop_cheat_caller_address(contract_address);

    // Transfer 10% from CREATOR1 to USER
    let transfer_percentage = 10_u256;

    start_cheat_caller_address(contract_address, creator1);
    let success = ownership_dispatcher
        .transfer_ownership_share(asset_id, creator1, user, transfer_percentage);
    stop_cheat_caller_address(contract_address);

    assert(success == true, 'Transfer should succeed');

    // Verify new ownership percentages
    assert!(
        ownership_dispatcher.get_owner_percentage(asset_id, creator1) == 40,
        "CREATOR1 should have 40% after transfer",
    );
    assert!(
        ownership_dispatcher.get_owner_percentage(asset_id, user) == 10,
        "USER should have 10% after transfer",
    );

    // Verify governance weights transferred proportionally
    let expected_governance_weight = (40 * 10)
        / 50; // (original_weight * percentage) / original_percentage
    assert!(
        ownership_dispatcher.get_governance_weight(asset_id, user) == expected_governance_weight,
        "Wrong governance weight after transfer",
    );
}

#[test]
#[should_panic(expected: "Only owner can transfer their share")]
fn test_ownership_transfer_unauthorized() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = IPAssetType::Art.into();
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Try to transfer CREATOR1's share as USER (unauthorized)
    start_cheat_caller_address(contract_address, USER());
    ownership_dispatcher.transfer_ownership_share(asset_id, creator1, user, 10_u256);
}

#[test]
#[should_panic(expected: "Insufficient ownership share")]
fn test_ownership_transfer_insufficient_share() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = IPAssetType::Art.into();
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Try to transfer more than owned (CREATOR3 has 20%, trying to transfer 25%)
    start_cheat_caller_address(contract_address, creator3);
    ownership_dispatcher.transfer_ownership_share(asset_id, creator3, user, 25_u256);
}

#[test]
fn test_update_metadata() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = IPAssetType::Art.into();
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Update metadata as one of the owners (CREATOR1)
    let new_metadata_uri: ByteArray = "ipfs://QmUpdatedMetadata";

    start_cheat_caller_address(contract_address, creator1);
    let success = asset_dispatcher.update_asset_metadata(asset_id, new_metadata_uri.clone());
    stop_cheat_caller_address(contract_address);

    assert(success == true, 'Metadata update should succeed');

    // Verify metadata was updated
    let asset_info = asset_dispatcher.get_asset_info(asset_id);
    assert(asset_info.metadata_uri == new_metadata_uri, 'Metadata should be updated');

    // Verify URI getter
    let uri = asset_dispatcher.get_asset_uri(asset_id);
    assert!(uri == new_metadata_uri, "URI getter should return updated metadata");
}

#[test]
#[should_panic(expected: "Only owners can update metadata")]
fn test_update_metadata_unauthorized() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = IPAssetType::Art.into();
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Try to update metadata as non-owner
    let new_metadata_uri: ByteArray = "ipfs://QmUpdatedMetadata";

    start_cheat_caller_address(contract_address, user);
    asset_dispatcher.update_asset_metadata(asset_id, new_metadata_uri);
}

#[test]
fn test_mint_additional_tokens() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = IPAssetType::Art.into();
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    let initial_supply = asset_dispatcher.get_total_supply(asset_id);
    let mint_amount = 500_u256;

    // Mint additional tokens as an owner (CREATOR1)
    start_cheat_caller_address(contract_address, creator1);
    let success = asset_dispatcher.mint_additional_tokens(asset_id, user, mint_amount);
    stop_cheat_caller_address(contract_address);

    assert(success == true, 'Minting should succeed');

    // Verify total supply increased
    let new_supply = asset_dispatcher.get_total_supply(asset_id);
    assert(new_supply == initial_supply + mint_amount, 'Total supply should increase');

    // Verify user received the tokens
    let user_balance = erc1155_dispatcher.balance_of(user, asset_id);
    assert!(user_balance == mint_amount, "User should receive minted tokens");
}

#[test]
#[should_panic(expected: "Only owners can mint tokens")]
fn test_mint_additional_tokens_unauthorized() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = IPAssetType::Art.into();
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Try to mint as non-owner
    start_cheat_caller_address(contract_address, user);
    asset_dispatcher.mint_additional_tokens(asset_id, user, 500_u256);
}

#[test]
fn test_access_control_functions() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = IPAssetType::Art.into();
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Test is_owner function
    assert(ownership_dispatcher.is_owner(asset_id, creator1) == true, 'CREATOR1 should be owner');
    assert(ownership_dispatcher.is_owner(asset_id, creator2) == true, 'CREATOR2 should be owner');
    assert(ownership_dispatcher.is_owner(asset_id, user) == false, 'USER should not be owner');

    // Test has_governance_rights function
    assert!(
        ownership_dispatcher.has_governance_rights(asset_id, creator1) == true,
        "CREATOR1 should have governance rights",
    );
    assert!(
        ownership_dispatcher.has_governance_rights(asset_id, user) == false,
        "USER should not have governance rights",
    );
}

#[test]
fn test_verify_asset_ownership() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    // Register asset first
    let asset_type = IPAssetType::Art.into();
    let metadata_uri: ByteArray = "ipfs://QmTestMetadata";
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);
    let asset_id = asset_dispatcher
        .register_ip_asset(
            asset_type, metadata_uri, creators, ownership_percentages, governance_weights,
        );
    stop_cheat_caller_address(contract_address);

    // Verify ownership verification returns true for registered asset
    assert!(
        asset_dispatcher.verify_asset_ownership(asset_id) == true,
        "Asset ownership should be verified",
    );

    assert!(
        asset_dispatcher.verify_asset_ownership(asset_id) == true,
        "Asset ownership should be verified",
    );

    // Test with non-existent asset
    assert!(
        asset_dispatcher.verify_asset_ownership(50_u256) == false,
        "Non-existent asset should not be verified",
    );
}

#[test]
fn test_multiple_asset_registration() {
    let (
        contract_address,
        ownership_dispatcher,
        asset_dispatcher,
        erc1155_dispatcher,
        _,
        _,
        _,
        owner_address,
    ) =
        setup();
    let (creators, ownership_percentages, governance_weights) = create_test_creators_data();

    let creator1: ContractAddress = *creators[0];
    let creator2: ContractAddress = *creators[1];
    let creator3: ContractAddress = *creators[2];
    let owner: ContractAddress = owner_address;
    let user: ContractAddress = USER();

    start_cheat_caller_address(contract_address, owner);

    // Register multiple assets
    let asset_id_1 = asset_dispatcher
        .register_ip_asset(
            IPAssetType::Art.into(),
            "ipfs://QmArt",
            creators,
            ownership_percentages,
            governance_weights,
        );

    let asset_id_2 = asset_dispatcher
        .register_ip_asset(
            'MUSIC', "ipfs://QmMusic", creators, ownership_percentages, governance_weights,
        );

    let asset_id_3 = asset_dispatcher
        .register_ip_asset(
            'LITERATURE',
            "ipfs://QmLiterature",
            creators,
            ownership_percentages,
            governance_weights,
        );

    stop_cheat_caller_address(contract_address);

    // Verify sequential asset IDs
    assert(asset_id_1 == 1, 'First asset should have ID 1');
    assert(asset_id_2 == 2, 'Second asset should have ID 2');
    assert(asset_id_3 == 3, 'Third asset should have ID 3');

    // Verify each asset has correct data
    let asset_info_1 = asset_dispatcher.get_asset_info(asset_id_1);
    let asset_info_2 = asset_dispatcher.get_asset_info(asset_id_2);
    let asset_info_3 = asset_dispatcher.get_asset_info(asset_id_3);

    assert(asset_info_1.asset_type == IPAssetType::Art.into(), 'Wrong asset type for asset 1');
    assert(asset_info_2.asset_type == 'MUSIC', 'Wrong asset type for asset 2');
    assert(asset_info_3.asset_type == 'LITERATURE', 'Wrong asset type for asset 3');
}

#[test]
fn test_mint_additional_tokens_overflow_protection() {
    let (contract_address, _, asset_dispatcher, erc1155_dispatcher, _, _, _, owner_address) =
        setup();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];
    let recipient = USER();

    let initial_supply = asset_dispatcher.get_total_supply(asset_id);
    let very_large_amount = Bounded::<u256>::MAX - initial_supply - 1;

    start_cheat_caller_address(contract_address, creator1);
    let success = asset_dispatcher.mint_additional_tokens(asset_id, recipient, very_large_amount);
    stop_cheat_caller_address(contract_address);

    assert!(success, "Minting large amount should succeed");

    let new_supply = asset_dispatcher.get_total_supply(asset_id);
    assert!(new_supply == initial_supply + very_large_amount, "Supply should update correctly");

    let recipient_balance = erc1155_dispatcher.balance_of(recipient, asset_id);
    assert!(recipient_balance == very_large_amount, "Recipient should receive minted tokens");
}

#[test]
#[should_panic(expected: "Only owners can update metadata")]
fn test_update_metadata_by_non_owner_after_transfer() {
    let (contract_address, ownership_dispatcher, asset_dispatcher, _, _, _, _, owner_address) =
        setup();
    let (asset_id, creators, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let creator1 = *creators[0];
    let new_owner = USER();
    let non_owner = deploy_erc1155_receiver();

    // Transfer all ownership away from creator1
    start_cheat_caller_address(contract_address, creator1);
    ownership_dispatcher.transfer_ownership_share(asset_id, creator1, new_owner, 50_u256);
    stop_cheat_caller_address(contract_address);

    // Try to update metadata as former owner
    start_cheat_caller_address(contract_address, creator1);
    asset_dispatcher.update_asset_metadata(asset_id, "ipfs://unauthorized-update");
}

#[test]
fn test_verify_asset_ownership_edge_cases() {
    let (contract_address, _, asset_dispatcher, _, _, _, _, owner_address) = setup();

    // Test with non-existent asset
    let non_existent_verification = asset_dispatcher.verify_asset_ownership(999_u256);
    assert!(!non_existent_verification, "Non-existent asset should not verify");

    // Test with zero asset ID
    let zero_verification = asset_dispatcher.verify_asset_ownership(0_u256);
    assert!(!zero_verification, "Zero asset ID should not verify");

    // Test with valid asset
    let (asset_id, _, _, _) = register_test_asset(
        contract_address, asset_dispatcher, owner_address,
    );
    let valid_verification = asset_dispatcher.verify_asset_ownership(asset_id);
    assert!(valid_verification, "Valid asset should verify");
}
