var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "waste mimic weekend proof wage case hero lumber cabbage ribbon waste focus";

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/", 0, 50);
      },
      network_id: '*'
    },

    develop: {
      accounts: 30
    }
  },
  compilers: {
    solc: {
      version: "^0.6.0"
    }
  }
};
