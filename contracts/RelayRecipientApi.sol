pragma solidity >=0.4.0 <0.6.0;

contract RelayRecipientApi {

    /**
     * return the relayHub of this contract.
     */
    function getHubAddr() public view returns (address);

    /**
     * return the contract's balance on the RelayHub.
     * can be used to determine if the contract can pay for incoming calls,
     * before making any.
     */
    function getRecipientBalance() public view returns (uint);
}
