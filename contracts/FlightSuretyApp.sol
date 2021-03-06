// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./Interface/FlightSuretyDataInterface.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;
    uint8 private constant STATUS_CODE_LATE_AIRLINE_PROCESSED = 60;

    address private contractOwner; // Account used to deploy contract
    IFlightSuretyData private flightSuretyData; // an interface that connects the app interface to the data interface;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    address[] airlineVotingTrack = new address[](0); // an array of airline voting tracking

    mapping(bytes32 => Flight) private flights;
    // mapping(address => address[]) private airlineVotingTrack; // an array of airline voting tracking.
    mapping(bytes32 => address[]) private insurees; // an array of insurees;

    uint8 private constant MINIMUM_AIRLINES_TO_VOTE = 4;
    uint256 private constant MAX_PREMIUM = 1 ether;

    event Purchased(
        address passenger,
        address airline,
        string flightCode,
        uint256 timestamp,
        uint256 value,
        uint256 insurees
    );

    event ProcessingLateFlight(
        address airline,
        string flightCode,
        uint256 timestamp,
        uint256 insurees
    );
    event CreditInsuree(
        address passenger,
        address airline,
        string flightCode,
        uint256 timestamp,
        uint256 value
    );

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
        // Modify to call data contract's status
        require(true, "Contract is currently not operational");
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
     * @dev Modifier that requires the airline to be registered and funded to register a new  airline
     */
    modifier onlyParticipatingAirline() {
        require(
            flightSuretyData.isParticipantRegistered(msg.sender),
            "Airline is not participating in this action"
        );
        _;
    }

    /**
     * @dev Modifier that requires only the new airlines to be registered
     */
    modifier onlyNewAirline(address _airline) {
        require(
            flightSuretyData.isAirlineRegistered(_airline) == false,
            "Airline is already registered"
        );
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address dataContract) public {
        contractOwner = msg.sender;
        flightSuretyData = IFlightSuretyData(dataContract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public pure returns (bool) {
        return true; // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *
     */
    function registerAirline(address _airline)
        external
        requireIsOperational
        onlyParticipatingAirline
        onlyNewAirline(_airline)
        returns (bool success, uint256 votes)
    {
        if (
            flightSuretyData.getRegisteredAirlinesNumber() <
            MINIMUM_AIRLINES_TO_VOTE
        ) {
            flightSuretyData.registerAirline(_airline);
            return (true, 1);
        } else {
            voteAirline(_airline);
        }
        return (success, 0);
    }

    /**
     * @dev vote for an airline to join the registration queue
     *
     */
    function voteAirline(address _airline)
        private
        returns (bool success, uint256 votings)
    {
        bool isDuplicate = false;
        for (uint256 i = 0; i < airlineVotingTrack.length; i++) {
            if (airlineVotingTrack[i] == msg.sender) {
                isDuplicate = true;
                break;
            }
        }

        require(!isDuplicate, "An airline can only vote once");
        airlineVotingTrack.push(msg.sender);

        uint256 votes = airlineVotingTrack.length;
        uint256 participants = flightSuretyData.getTheParticipantsNumber();

        if (votes > participants.div(2)) {
            flightSuretyData.registerAirline(_airline);
            airlineVotingTrack = new address[](0);
            return (true, votes);
        }

        return (false, votes);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(string calldata flightCode, uint256 timestamp)
        external
        requireIsOperational
        onlyParticipatingAirline
    {
        bytes32 flightKey = getFlightKey(msg.sender, flightCode, timestamp);
        require(
            !flights[flightKey].isRegistered,
            "Flight has already been registered"
        );
        flights[flightKey] = Flight(
            true,
            STATUS_CODE_UNKNOWN,
            timestamp,
            msg.sender
        );
    }

    /**
     * @dev check if the flight is registered
     *
     */
    function isFlightRegistered(
        address airline,
        string memory flightCode,
        uint256 timestamp
    ) public view requireIsOperational returns (bool) {
        bytes32 flightKey = getFlightKey(airline, flightCode, timestamp);
        return flights[flightKey].isRegistered;
    }

    /**
     * @dev purchase flight insurance
     *
     */
    function buy(
        address _airline,
        string memory flightCode,
        uint256 timestamp
    ) external payable requireIsOperational {
        bytes32 flightKey = getFlightKey(_airline, flightCode, timestamp);

        // keep track of the flight insurees
        insurees[flightKey].push(msg.sender);

        // pay upto the cap which is 1 ether
        if (msg.value > MAX_PREMIUM) {
            flightSuretyData.buy{value: MAX_PREMIUM}(
                _airline,
                msg.sender,
                flightCode,
                timestamp
            );
            emit Purchased(
                msg.sender,
                _airline,
                flightCode,
                timestamp,
                MAX_PREMIUM,
                insurees[flightKey].length
            );
        } else {
            flightSuretyData.buy{value: msg.value}(
                _airline,
                msg.sender,
                flightCode,
                timestamp
            );
            emit Purchased(
                msg.sender,
                _airline,
                flightCode,
                timestamp,
                msg.value,
                insurees[flightKey].length
            );
        }
    }

    /**
     * @dev get passenger bougth flight insurance
     *
     */
    function getPassengerInsurance(
        address airline,
        string calldata flight,
        uint256 timestamp
    ) external view requireIsOperational returns (uint256) {
        return
            flightSuretyData.getInsurance(
                msg.sender,
                airline,
                flight,
                timestamp
            );
    }

    /**
     * @dev pay the passenger on withdraw
     *
     */
    function pay() external requireIsOperational {
        flightSuretyData.pay(msg.sender);
    }

    /**
     * @dev pay the passenger credit balance
     *
     */
    function getBalance() external view requireIsOperational returns(uint256) {
        return flightSuretyData.getBalance(msg.sender);
    }

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal requireIsOperational {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        require(
            flights[flightKey].statusCode != STATUS_CODE_LATE_AIRLINE_PROCESSED,
            "the airline has been processed"
        );
        flights[flightKey].statusCode = statusCode;

        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            emit ProcessingLateFlight(
                airline,
                flight,
                timestamp,
                insurees[flightKey].length
            );
            for (uint256 i = 0; i < insurees[flightKey].length; i++) {
                address passenger = insurees[flightKey][i];
                uint256 passengerInsurance = flightSuretyData.getInsurance(
                    passenger,
                    airline,
                    flight,
                    timestamp
                );

                if (passengerInsurance > 0) {
                    emit CreditInsuree(
                        passenger,
                        airline,
                        flight,
                        timestamp,
                        passengerInsurance.mul(15).div(10)
                    );

                    flightSuretyData.creditInsurees(
                        passenger,
                        airline,
                        flight,
                        timestamp,
                        passengerInsurance.mul(15).div(10)
                    );
                }
            }

            flights[flightKey].statusCode = STATUS_CODE_LATE_AIRLINE_PROCESSED;
        }
    }

    /**
     * @dev Called after oracle has updated flight status
     *
     */

    function checkFlightStatus(
        address airline,
        string calldata flight,
        uint256 timestamp
    ) external view requireIsOperational returns (uint256) {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        return flights[flightKey].statusCode;
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address airline,
        string calldata flight,
        uint256 timestamp
    ) external requireIsOperational {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester; // Account that requested status
        bool isOpen; // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes() external view returns (uint8[3] memory) {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint8 statusCode
    ) external {
        require(
            (oracles[msg.sender].indexes[0] == index) ||
                (oracles[msg.sender].indexes[1] == index) ||
                (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );

        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        require(
            oracleResponses[key].isOpen,
            "Flight or timestamp do not match oracle request"
        );

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (
            oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES
        ) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account)
        internal
        returns (uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - nonce++), account)
                )
            ) % maxValue
        );

        if (nonce > 250) {
            nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion
}
