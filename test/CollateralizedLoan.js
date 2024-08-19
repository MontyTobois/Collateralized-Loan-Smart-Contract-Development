// Importing necessary modules and functions from Hardhat and Chai for testing
const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

// Describing a test suite for the CollateralizedLoan contract
describe("CollateralizedLoan", function () {
  // A fixture to deploy the contract before each test. This helps in reducing code repetition.
  async function deployCollateralizedLoanFixture() {
    // Deploying the CollateralizedLoan contract and returning necessary variables
    const CollateralizedLoan = await ethers.getContractFactory(
      "CollateralizedLoan"
    );
    const [borrower, lender] = await ethers.getSigners();

    const collateralizedLoan = await CollateralizedLoan.deploy();

    return { collateralizedLoan, borrower, lender };
  }

  // Test suite for the loan request functionality
  describe("Loan Request", function () {
    it("Should let a borrower deposit collateral and request a loan", async function () {
      // Loading the CollateralizedLoan fixture
      const { collateralizedLoan, borrower } = await loadFixture(
        deployCollateralizedLoanFixture
      );

      const collateralAmount = ethers.parseEther("1"); // 1 ETH as collateral
      const interestRate = 10; // 10%
      const duration = 60 * 60 * 24 * 7; // 7 days duration
      const timeLeft = (await time.latest()) + duration;

      await collateralizedLoan
        .connect(borrower)
        .depositCollateralAndRequestLoan(interestRate, timeLeft, {
          value: collateralAmount,
        });

      const loan = await collateralizedLoan.loans(0);

      expect(loan.borrower).to.equal(borrower.address);
      expect(loan.collateralAmount).to.equal(collateralAmount);
      expect(loan.loanAmount).to.equal(collateralAmount * BigInt(2)); // 2x the collateral amount
      expect(loan.interestRate).to.equal(interestRate);
      expect(loan.isFunded).to.be.false;
      expect(loan.isRepaid).to.be.false;
    });
  });

  // Test suite for funding a loan
  describe("Funding a Loan", function () {
    it("Allows a lender to fund a requested loan", async function () {
      // Loading the CollateralizedLoan fixture
      const { collateralizedLoan, borrower, lender } = await loadFixture(
        deployCollateralizedLoanFixture
      );

      const collateralAmount = ethers.parseEther("1"); // 1 ETH as collateral
      const interestRate = 10; // 10%
      const duration = 60 * 60 * 24 * 7; // 7 days duration
      const timeLeft = (await time.latest()) + duration;

      await collateralizedLoan
        .connect(borrower)
        .depositCollateralAndRequestLoan(interestRate, timeLeft, {
          value: collateralAmount,
        });

      const loanAmount = collateralAmount * BigInt(2);

      await expect(
        collateralizedLoan.connect(lender).fundLoan(0, { value: loanAmount })
      )
        .to.emit(collateralizedLoan, "LoanFunded")
        .withArgs(0, lender.address, loanAmount);

      const loan = await collateralizedLoan.loans(0);
      expect(loan.isFunded).to.be.true;
      expect(loan.lender).to.equal(lender.address);
    });
  });

  // Test suite for repaying a loan
  describe("Repaying a Loan", function () {
    it("Enables the borrower to repay the loan fully", async function () {
      // Loading the CollateralizedLoan fixture
      const { collateralizedLoan, borrower, lender } = await loadFixture(
        deployCollateralizedLoanFixture
      );

      const collateralAmount = ethers.parseEther("1"); // 1 ETH as collateral
      const interestRate = 10; // 10%
      const duration = 60 * 60 * 24 * 7; // 7 days duration
      const timeLeft = (await time.latest()) + duration;

      await collateralizedLoan
        .connect(borrower)
        .depositCollateralAndRequestLoan(interestRate, timeLeft, {
          value: collateralAmount,
        });

      const loanAmount = BigInt(collateralAmount * BigInt(2));
      await collateralizedLoan
        .connect(borrower)
        .fundLoan(0, { value: loanAmount });

      const repayAmount =
        loanAmount + (loanAmount * BigInt(interestRate)) / BigInt(100); // Ensure all parts of the expression are BigInt
      // Allows the borrower to repay the loan
      await expect(
        collateralizedLoan
          .connect(borrower)
          .repayLoan(0, { value: repayAmount })
      )
        // Emits event CollateralClaim
        .to.emit(collateralizedLoan, "LoanRepaid")
        .withArgs(0, borrower.address, repayAmount);

      const loan = await collateralizedLoan.loans(0);
      expect(loan.isRepaid).to.be.true;
    });
  });

  // Test suite for claiming collateral
  describe("Claiming Collateral", function () {
    it("Permits the lender to claim collateral if the loan isn't repaid on time", async function () {
      // Loading the CollateralizedLoan fixture
      const { collateralizedLoan, borrower, lender } = await loadFixture(
        deployCollateralizedLoanFixture
      );

      const collateralAmount = ethers.parseEther("1"); // 1 ETH as collateral
      const interestRate = 10; // 10%
      const duration = 60 * 60 * 24 * 7; // 7 days duration
      const timeLeft = (await time.latest()) + duration;

      // The borrow must pay back the loan  to the Lender
      await collateralizedLoan
        .connect(borrower)
        .depositCollateralAndRequestLoan(interestRate, duration, {
          value: collateralAmount,
        });

      // Allows the lender to claim the Collateral
      const loanAmount = BigInt(collateralAmount * BigInt(2));
      await collateralizedLoan
        .connect(lender)
        .fundLoan(0, { value: loanAmount });

      // Simulate the passage of time
      await ethers.provider.send("evm_increaseTime", [timeLeft]);

      // Emits event CollateralClaim
      await expect(collateralizedLoan.connect(lender).claimCollateral(0))
        .to.emit(collateralizedLoan, "CollateralClaim")
        .withArgs(0, lender.address, collateralAmount);

      // Loan count and amount goes back to 0
      const loan = await collateralizedLoan.loans(0);
      expect(loan.collateralAmount).to.equal(0);
    });
  });
});
