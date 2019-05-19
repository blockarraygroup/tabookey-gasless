pragma solidity >=0.4.0 <0.6.0;

// Contract that implements the relay recipient protocol.  Inherited by Gatekeeper, or any other relay recipient.
//
// The recipient contract is responsible to:
// * pass a trusted RelayHub singleton to the constructor.
// * Implement acceptRelayedCall, which acts as a whitelist/blacklist of senders.  It is advised that the recipient's owner will be able to update that list to remove abusers.
// * In every function that cares about the sender, use "address sender = getSender()" instead of msg.sender.  It'll return msg.sender for non-relayed transactions, or the real sender in case of relayed transactions.

import "./RelayRecipientApi.sol";
import "./RelayHub.sol";
import "@0x/contracts-utils/contracts/src/LibBytes.sol";

contract RelayRecipient is RelayRecipientApi {

    RelayHub private relayHub; // The RelayHub singleton which is allowed to call us

	function getHubAddr() public view returns (address) {
		return address(relayHub);
	}

    /**
     * initialize the relayhub.
     * contracts usually call this method from the constructor (using a constract RelayHub, or receiving
     * one in the constructor)
     * This method might also be called by the owner, in order to use a new RelayHub - since the RelayHub
     * itself is not an upgradable contract.
     */
    function initRelayHub(RelayHub _rhub) internal {
        require(relayHub == RelayHub(0), "initRelayHub: rhub already set");
        setRelayHub(_rhub);
    }
    
    function setRelayHub(RelayHub _rhub) internal {
        // Normally called just once, during initRelayHub.
        // Left as a separate internal function, in case a contract wishes to have its own update mechanism for RelayHub.
        relayHub = _rhub;

        //attempt a read method, just to validate the relay is a valid RelayHub contract.
        getRecipientBalance();
    }

    function getRelayHub() internal view returns (RelayHub) {
        return relayHub;
    }

    /**
     * return the balance of this contract.
     * Note that this method will revert on configuration error (invalid relay address)
     */
    function getRecipientBalance() public view returns (uint) {
        return getRelayHub().balanceOf(address(this));
    }

    function getSenderFromData(address origSender, bytes memory msgData) public view returns(address) {
        address sender = origSender;
        if (origSender == getHubAddr() ) {
            // At this point we know that the sender is a trusted RelayHub, so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data
            sender = LibBytes.readAddress(msgData, msgData.length - 20);
        }
        return sender;
    }

    function getSender() public view returns(address) {
        return getSenderFromData(msg.sender, msg.data);
    }

    function getMessageData() public view returns(bytes memory) {
        bytes memory origMsgData = msg.data;
        if (msg.sender == getHubAddr()) {
            // At this point we know that the sender is a trusted RelayHub, so we trust that the last bytes of msg.data are the verified sender address.
            // extract original message data from the start of msg.data
            origMsgData = new bytes(msg.data.length - 20);
            for (uint256 i = 0; i < origMsgData.length; i++)
            {
                origMsgData[i] = msg.data[i];
            }
        }
        return origMsgData;
    }

    /*
	 * Contract must inherit and re-implement this method.
	 *  @return "0" if the the contract is willing to accept the charges from this sender, for this function call.
	 *  	any other value is a failure. actual value is for diagnostics only.
	 *** Note :values below 10 are reserved by canRelay
	 *  @param relay the relay that attempts to relay this function call.
	 * 			the contract may restrict some encoded functions to specific known relays.
	 *  @param from the sender (signer) of this function call.
	 *  @param encodedFunction the encoded function call (without any ethereum signature).
	 * 			the contract may check the method-id for valid methods
	 *  @param gasPrice - the gas price for this transaction
	 *  @param transactionFee - the relay compensation (in %) for this transaction
	 *  @param approval - first 65 bytes are checked by the RelayHub and reserved for the sender's signature, and the rest is
     *           available for dapps in their specific use-cases
	 */
    function acceptRelayedCall(address relay, address from, bytes memory encodedFunction, uint gasPrice, uint transactionFee, bytes memory approval) public view returns(uint32);

    /**
     * This method is called after the relayed call.
     * It may be used to record the transaction (e.g. charge the caller by some contract logic) for this call.
     * the method is given all parameters of acceptRelayedCall, and also the success/failure status and actual used gas.
     * - success - true if the relayed call succeeded, false if it reverted
     * - usedGas - gas used up to this point. Note that gas calculation (for the purpose of compensation
     *   to the relay) is done after this method returns.
     */
    function postRelayedCall(address relay, address from, bytes memory encodedFunction, bool success, uint usedGas, uint transactionFee) public;
}

