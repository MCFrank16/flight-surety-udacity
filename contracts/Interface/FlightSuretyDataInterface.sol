// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

interface IFlightSuretyData {
    function registerAirline(address _airline) external;

    function getRegisteredAirlinesNumber() external view returns (uint256);

    function isAirlineRegistered(address _airline) external view returns (bool);

    function isParticipantRegistered(address _airline)
        external
        view
        returns (bool);

    function getTheParticipantsNumber() external view returns (uint256);

    function buy(
        address _airline,
        address passenger,
        string calldata flight,
        uint256 timestamp
    ) external payable;

    function getInsurance(
        address passenger,
        address airline,
        string calldata flight,
        uint256 timestamp
    ) external view returns (uint256);

    function creditInsurees(
        address passenger,
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint256 credit
    ) external;

    function pay(address payable passenger) external;

    function getBalance(address passenger) external view returns(uint256);
}
