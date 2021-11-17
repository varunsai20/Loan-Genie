const LoanGenie = artifacts.require("LoanGenie");

module.exports = function (deployer) {
  deployer.deploy(LoanGenie, 1, 5);
};
