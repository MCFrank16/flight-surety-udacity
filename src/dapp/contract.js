import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';


let config = null;
export default class Contract {
    constructor(network, callback) {

        config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.initialize(callback);
        this.owner = null;
        this.firstAirline = null;
        this.airlines = [];
        this.passengers = [];
        this.flights = []
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {

            this.owner = accts[0];

            this.firstAirline = accts[1];

            let counter = 1;

            while (this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while (this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    isOperational(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner }, callback);

    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        }
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner }, (error, result) => {
                console.log(error)
                console.log(result)
                callback(error, payload);
            });
    }

    buyInsurance(flight, insuranceValue, callback) {
        let self = this;
        let payload = {
            airline: self.firstAirline,
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        }
        self.flightSuretyApp.methods
            .buy(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.passengers[0], value: this.web3.utils.toWei(insuranceValue, "ether"), gas: 3000000 }, (error, result) => {
                console.log(error)
                console.log(result)
                callback(error, result);
            });
    }

    withdrawCredits(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .pay()
            .send({ from: self.passengers[0], gas: 3000000 }, (error, result) => {
                console.log(error)
                console.log(result)
                callback(error, result);
            });
    }
}