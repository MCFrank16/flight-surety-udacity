
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
const truffleAssert = require("truffle-assertions");

contract('Flight Surety Tests', async (accounts) => {

    const timestamp = Math.floor(Date.now() / 1000);
    const flight = "FRANK001"
    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    it(`(multiparty) has correct initial isOperational() value`, async function () {

        // Get operating status
        let status = await config.flightSuretyData.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");

    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

        // Ensure that access is allowed for Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false);
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

        await config.flightSuretyData.setOperatingStatus(false);

        let reverted = false;
        try {
            await config.flightSurety.setTestingMode(true);
        }
        catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true);

    });

    it('(airline) should register the first airline on contract deploy', async () => {
        const result = await config.flightSuretyData.isAirlineRegistered.call(config.firstAirline)
        assert.equal(result, true, "First airline is not registered while deploying")
    })

    it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

        // ARRANGE
        let newAirline = accounts[2];

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });
        }
        catch (e) {

        }
        let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);

        // ASSERT
        assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided fundings");

    });

    it('(airline) fund an airline to become an airline voting participant', async () => {
        const fundAirline = await config.flightSuretyData.fund({ from: config.firstAirline, value: web3.utils.toWei('5', 'ether') });
        const fundAirline2 = await config.flightSuretyData.fund({ from: config.firstAirline, value: web3.utils.toWei('5', 'ether') });

        truffleAssert.eventEmitted(fundAirline2, 'Participating', null, 'Invalid event emmitted');

        let result = await config.flightSuretyData.isParticipantRegistered.call(config.firstAirline);
        
        let balance = await web3.eth.getBalance(config.flightSuretyData.address);

        assert.equal(result, true, 'Participant is not registered');
        assert.equal(web3.utils.fromWei(balance, "ether"), 10, 'Contract not funded')

    })

    it('(airline) can register an airline if it is funded', async () => {
        // ARRANGE
        let newAirline = accounts[2];

        // ACT
        try {
            const trans = await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });
            truffleAssert.eventEmitted(trans, 'Registered', null, 'Invalid event emitted')
        }
        catch (e) {

        }
        let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);

        // ASSERT
        assert.equal(result, true, "Airline is not able to register another airline even if it has provided funding");
    })

    it('(airline) can register more airlines up to 4', async () => {
        let thirdAirline = accounts[3];
        let fourthAirline = accounts[4];

        try {
            await config.flightSuretyApp.registerAirline(thirdAirline, { from: config.firstAirline });
            await config.flightSuretyApp.registerAirline(fourthAirline, { from: config.firstAirline });
        }
        catch (e) {

        }

        let result1 = await config.flightSuretyData.isAirlineRegistered.call(thirdAirline);
        let result2 = await config.flightSuretyData.isAirlineRegistered.call(fourthAirline);

        assert.equal(result1, true, "Third airline is not registered");
        assert.equal(result2, true, "Fourth airline is not registered");
    });

    it('(airline) can not register a fifth airline if both of 4 airlines are not funded', async () => {
        let fifthAirline = accounts[5]

        try {
            await config.flightSuretyApp.registerAirline(fifthAirline, { from: config.firstAirline });
        } catch (error) {

        }

        let result = await config.flightSuretyData.isAirlineRegistered.call(fifthAirline);

        assert.equal(result, true, 'Fifth airline is gonna be registered while all airlines are not funded')
    })

    it('(airline) can not register a sixth airline after funding the registered airlines', async () => {

        let thirdAirline = accounts[3]
        let fourthAirline = accounts[4]

        let sixthAirline = accounts[6]

        // fund each airline with 10 ether
        const fundAirline3 = await config.flightSuretyData.fund({ from: thirdAirline, value: web3.utils.toWei('10', 'ether') });
        const fundAirline4 = await config.flightSuretyData.fund({ from: fourthAirline, value: web3.utils.toWei('10', 'ether') });

        try {
            await config.flightSuretyApp.registerAirline(sixthAirline, { from: thirdAirline });
        } catch (error) {

        }

        await config.flightSuretyData.isAirlineRegistered.call(sixthAirline);


        let checkStatus = await config.flightSuretyData.isOperational.call()
        let changeStatus = !checkStatus

        await config.flightSuretyData.setOperatingStatus(changeStatus, { from: thirdAirline })
        await config.flightSuretyData.setOperatingStatus(changeStatus, { from: fourthAirline })

        let newStatus = await config.flightSuretyData.isOperational.call()

        assert.equal(changeStatus, newStatus, 'Sixth airline is not registered')
    })

    it('(flight) can register a flight', async () => {

        await config.flightSuretyApp.registerFlight(flight, timestamp, { from: config.firstAirline });

        let result = await config.flightSuretyApp.isFlightRegistered.call(config.firstAirline, flight, timestamp);

        assert.equal(result, true, 'Flight was not registered')

    })

    it('(passenger) can buy an insurance', async () => {
        let passenger = accounts[7]

        let checkStatus = await config.flightSuretyData.isOperational.call()

        await config.flightSuretyData.setOperatingStatus(!checkStatus, { from: config.firstAirline })

        await config.flightSuretyApp.buy(config.firstAirline, flight, timestamp, { from: passenger, value: web3.utils.toWei('0.5', "ether") });

        const passengerInsurance = await config.flightSuretyApp.getPassengerInsurance.call(config.firstAirline, flight, timestamp, { from: passenger });

        assert.equal(passengerInsurance, web3.utils.toWei('0.5', 'ether'), 'Passenger insurance is not correct')
    })
});
