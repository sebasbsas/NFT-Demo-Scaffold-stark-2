use starknet::ContractAddress;

// NFT contract for scaffold-stark 2 project
// Owner (deployer) can mint NFTs (title + image). Owner can assign a minted NFT to a user (claim)
// Anyone can query NFT metadata and owner. Users can get their NFT count and fetch by index.

#[starknet::interface]
pub trait IYourContract<TContractState> {
    fn mint_nft(ref self: TContractState, title: ByteArray, image: ByteArray);
    fn assign_to_caller(ref self: TContractState, nft_id: u256);
    fn get_user_nft_count(self: @TContractState, user: ContractAddress) -> u256;
    fn get_user_nft_at(self: @TContractState, user: ContractAddress, index: u256) -> u256;
    fn view_nft(self: @TContractState, nft_id: u256) -> (ByteArray, ByteArray, ContractAddress);
}

#[starknet::contract]
pub mod YourContract {
        use openzeppelin_access::ownable::OwnableComponent;
        use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
        use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};
        use starknet::{ContractAddress, get_caller_address};
        use core::integer::u256;
        use core::byte_array::ByteArray;
        use super::IYourContract;

        component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

        #[abi(embed_v0)]
        impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
        impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

        #[event]
        #[derive(Drop, starknet::Event)]
        enum Event {
            #[flat]
            OwnableEvent: OwnableComponent::Event,
            NFTMinted: NFTMinted,
            NFTAssigned: NFTAssigned,
        }

        #[derive(Drop, starknet::Event)]
        struct NFTMinted {
            #[key]
            minter: ContractAddress,
            #[key]
            nft_id: u256,
        }

        #[derive(Drop, starknet::Event)]
        struct NFTAssigned {
            #[key]
            nft_id: u256,
            #[key]
            to: ContractAddress,
        }

        #[storage]
        struct Storage {
            total_supply: u256,
            nft_title: Map<u256, ByteArray>,
            nft_image: Map<u256, ByteArray>,
            nft_owner: Map<u256, ContractAddress>,
            user_nft_count: Map<ContractAddress, u256>,
            user_nft_at: Map<(ContractAddress, u256), u256>,
            #[substorage(v0)]
            ownable: OwnableComponent::Storage,
        }

        #[constructor]
        fn constructor(ref self: ContractState, owner: ContractAddress) {
            self.total_supply.write(0);
            self.ownable.initializer(owner);
        }

        #[abi(embed_v0)]
        impl YourContractImpl of IYourContract<ContractState> {
            fn mint_nft(ref self: ContractState, title: ByteArray, image: ByteArray) {
                self.ownable.assert_only_owner();

                let id = self.total_supply.read() + 1;
                self.total_supply.write(id);

                self.nft_title.write(id, title);
                self.nft_image.write(id, image);

                // mark unassigned
                let zero: ContractAddress = 0.try_into().unwrap();
                self.nft_owner.write(id, zero);

                self.emit(NFTMinted { minter: self.ownable.owner(), nft_id: id });
            }

            fn assign_to_caller(ref self: ContractState, nft_id: u256) {
                self.ownable.assert_only_owner();
                let to = get_caller_address();
                let current = self.nft_owner.read(nft_id);
                let zero: ContractAddress = 0.try_into().unwrap();
                assert!(current == zero, "NFT already assigned");

                self.nft_owner.write(nft_id, to);

                let count = self.user_nft_count.read(to);
                let next = count + 1;
                self.user_nft_at.write((to, next), nft_id);
                self.user_nft_count.write(to, next);

                self.emit(NFTAssigned { nft_id, to });
            }

            fn get_user_nft_count(self: @ContractState, user: ContractAddress) -> u256 {
                self.user_nft_count.read(user)
            }

            fn get_user_nft_at(self: @ContractState, user: ContractAddress, index: u256) -> u256 {
                self.user_nft_at.read((user, index))
            }

            fn view_nft(self: @ContractState, nft_id: u256) -> (ByteArray, ByteArray, ContractAddress) {
                let title = self.nft_title.read(nft_id);
                let image = self.nft_image.read(nft_id);
                let owner = self.nft_owner.read(nft_id);
                (title, image, owner)
            }
        }
    }
                        //self.ownable.assert_only_owner();
