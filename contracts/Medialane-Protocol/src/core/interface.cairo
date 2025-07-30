use starknet::ContractAddress;
use crate::core::types::*;

#[starknet::interface]
pub trait IMedialane<TState> {
    fn register_order(ref self: TState, order: Order);
    fn fulfill_order(ref self: TState, order: Order, fulfiller: ContractAddress);
    fn cancel_order(ref self: TState, order: Order);
    fn get_order_status(self: @TState, order_hash: felt252) -> OrderStatus;
    fn get_order_hash(
        self: @TState, parameters: OrderParameters, signer: ContractAddress,
    ) -> felt252;
}
