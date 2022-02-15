// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    uint256 private registeredAirlinesNumber = 0;
    uint256 private participants = 0;

    mapping(address => bool) private authorizedCallerContracts;

    mapping(address => bool) private registeredAirlines; // a list of registered airlines
    mapping(address => bool) private participatingAirlines; // a list of participants in airline voting
    mapping(address => uint256) private fundings; // a list of airlines funding, this will aid in knowing voting participants

    mapping(address => mapping(bytes32 => uint256)) private passengerInsurances;
    mapping(address => uint256) private passengerAccount;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    // event to be emitted when the airline is registered
    event Registered(address airlineAddress);

    // event to be emitted when the airline is a participant in voting
    event Participating(address airlineAddress);

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor(address _initialAirline) public {
        contractOwner = msg.sender;
        registeredAirlines[_initialAirline] = true;
        registeredAirlinesNumber++;
        emit Registered(_initialAirline);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
     * @dev Modifier that requires the "airline" to be registered
     */
    modifier requireIsAirlineRegistered() {
        require(
            registeredAirlines[msg.sender] == true,
            "Airline is not registered"
        );
        _;
    }

    /**
     * @dev Modifier that check the "caller contract" to be authorized
     */
    modifier requireIsAuthorized() {
        require(
            authorizedCallerContracts[msg.sender] == true,
            "Caller is not authorized"
        );
        _;
    }

    /**
     * @dev Modifier that requires the "airline" to be a participant
     */
    modifier onlyParticipatingAirline() {
        require(
            participatingAirlines[msg.sender] == true,
            "Airline is not a voting participant"
        );
        _;
    }

    /**
     * @dev Modifier that check the "airline" to not be a participant
     */
    modifier onlyNonParticipatingAirline() {
        require(
            participatingAirlines[msg.sender] == false,
            "Airline is a voting participant"
        );
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */
    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode) external {
        operational = mode;
    }

    /**
     * @dev authorized caller contract
     *
     */
    function authorizeCaller(address contactAddress)
        external
        requireContractOwner
    {
        authorizedCallerContracts[contactAddress] = true;
    }

    /**
     * @dev remove authorized caller contract FlightSuretyApp
     */
    function removeAuthorizedCaller(address contractAddress)
        external
        requireContractOwner
    {
        delete authorizedCallerContracts[contractAddress];
    }

    /**
     * @dev check if caller is Authorized
     */
    function isCallerAuthorized(address contractAddress)
        public
        view
        requireContractOwner
        returns (bool)
    {
        return authorizedCallerContracts[contractAddress];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline(address _airline)
        external
        requireIsOperational
        requireIsAuthorized
    {
        registeredAirlines[_airline] = true;
        registeredAirlinesNumber++;
        emit Registered(_airline);
    }

    /**
     * @dev check if an airline is registered
     *
     */
    function isAirlineRegistered(address _airline) public view returns (bool) {
        return registeredAirlines[_airline];
    }

    /**
     * @dev get a number of registered airlines
     *
     */
    function getRegisteredAirlinesNumber() external view returns (uint256) {
        return registeredAirlinesNumber;
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy(
        address _airline,
        address passenger,
        string calldata flight,
        uint256 timestamp
    ) external payable requireIsOperational requireIsAuthorized {
        bytes32 flightKey = getFlightKey(_airline, flight, timestamp);
        passengerInsurances[passenger][flightKey] = passengerInsurances[
            passenger
        ][flightKey].add(msg.value);
    }

    /**
     *  @dev get passenger insurance
     * check if the passenger has bought a flight insurance
     */
    function getInsurance(
        address passenger,
        address airline,
        string calldata flight,
        uint256 timestamp
    ) external view returns (uint256) {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        return passengerInsurances[passenger][flightKey];
    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees(
        address passenger,
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint256 credit
    ) external requireIsOperational requireIsAuthorized {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        delete passengerInsurances[passenger][flightKey];
        passengerAccount[passenger] = passengerAccount[passenger].add(credit);
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     * this will be triggered when the passengers choose to withdraw the cash
     */
    function pay(address payable passenger)
        external
        requireIsOperational
        requireIsAuthorized
    {
        uint256 credit = passengerAccount[passenger];
        require(credit > 0, "Not enough credits to withdraw");
        passengerAccount[passenger] = 0;
        passenger.transfer(credit);
    }

    /**
     *  @dev get passenger credit in their account
     *
     */
    function getBalance(address passenger)
        external
        view
        requireIsOperational
        requireIsAuthorized
        returns (uint256)
    {
        uint256 credit = passengerAccount[passenger];
        return credit;
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund()
        public
        payable
        requireIsOperational
        requireIsAirlineRegistered
        onlyNonParticipatingAirline
    {
        // check the current funding
        uint256 currentFunds = fundings[msg.sender];
        currentFunds = currentFunds.add(msg.value);
        fundings[msg.sender] = currentFunds;

        if (
            currentFunds >= 10 ether &&
            participatingAirlines[msg.sender] == false
        ) {
            participatingAirlines[msg.sender] = true;
            participants++;
            emit Participating(msg.sender);
        }
    }

    /**
     *  @dev check if the caller is the participants
     *
     */
    function isParticipantRegistered(address _airline)
        external
        view
        returns (bool)
    {
        return participatingAirlines[_airline];
    }

    /**
     *  @dev retrieve the number of participants
     *
     */
    function getTheParticipantsNumber() external view returns (uint256) {
        return participants;
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    fallback() external payable {
        fund();
    }

    receive() external payable {
        fund();
    }
}
