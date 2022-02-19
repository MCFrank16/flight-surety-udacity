const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');
const Web3 = require('web3')

module.exports = async (deployer, network, accounts) => {

    let firstAirline = accounts[1];

    await deployer.deploy(FlightSuretyData, firstAirline);

    const dataContract = await FlightSuretyData.deployed();

    const appContract = await deployer.deploy(FlightSuretyApp, FlightSuretyData.address);

    // authorize the app contract
    await dataContract.authorizeCaller(FlightSuretyApp.address);

    // fund the first airline
    await dataContract.fund({
        from: firstAirline,
        value: Web3.utils.toWei('10', 'ether')
    })

    // Add some dummy flights data for demo purposes
    const timestamp = Math.floor(Date.now() / 1000);
    await appContract.registerFlight('FLIGHT-001', timestamp, { from: firstAirline });
    await appContract.registerFlight('FLIGHT-002', timestamp, { from: firstAirline });
    await appContract.registerFlight('FLIGHT-003', timestamp, { from: firstAirline });

    let config = {
        localhost: {
            url: 'http://localhost:7545',
            dataAddress: FlightSuretyData.address,
            appAddress: FlightSuretyApp.address
        }
    }

    fs.writeFileSync(__dirname + '/../src/dapp/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
    fs.writeFileSync(__dirname + '/../src/server/config.json', JSON.stringify(config, null, '\t'), 'utf-8');

}