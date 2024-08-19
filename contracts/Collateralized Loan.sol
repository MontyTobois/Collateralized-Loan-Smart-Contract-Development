// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Collateralized Loan Contract
contract CollateralizedLoan {
    // Define the structure of a loan
    struct Loan {
        address borrower;
        // A field for the lender's address
        address lender;
        uint collateralAmount;
        // A fields for loan amount, interest rate, due date, isFunded, isRepaid
        uint loanAmount;
        uint interestRate; //Interest rate in percentages 
        uint dueDate; // Timestamp when the loan is due
        bool isFunded;
        bool isRepaid;
    }

    // Create a mapping to manage the loans
    mapping(uint => Loan) public loans;
    uint public nextLoanId;

    // Events for loan requested, funded, repaid, and collateral claimed
    event LoanRequested(uint loanId, address borrower, uint collateralAmount, uint loanAmount, uint interestRate, uint dueDate);
    event LoanFunded(uint loanId, address borrower, uint loanAmount);
    event LoanRepaid(uint loanId, address lender, uint loanAmount);
    event CollateralClaim(uint loanId, address lender,  uint collateralAmount);

    // Custom Modifiers
    // Modifier to check if a loan exists
    modifier loanExists(uint loanId) {
        require(loanId < nextLoanId, "Loan does not exist.");
        _;
    }
    // Modifier to ensure a loan is not already funded
    modifier notFunded(uint loanId) {
        require(!loans[loanId].isFunded, "Loan is funded already.");
        _;
    }

    // Function to deposit collateral and request a loan
    function depositCollateralAndRequestLoan(uint _interestRate, uint _duration) external payable {
        // Check if the collateral is more than 0
        require(msg.value > 0, "collateral amount must be greater the 0");
        // Hint: Calculate the loan amount based on the collateralized amount
        uint loanAmount = msg.value * 2;
        uint dueDate = block.timestamp + _duration;
        // Create a new loan in the loans mapping
        loans[nextLoanId] = Loan({
            borrower: msg.sender,
            lender: address(0),
            collateralAmount: msg.value,
            loanAmount: loanAmount,
            interestRate: _interestRate,
            dueDate: dueDate,
            isFunded: false,
            isRepaid: false
        });
        // Emits an event for Loan Request
        emit LoanRequested(nextLoanId, msg.sender, msg.value, loanAmount, _interestRate, dueDate);
       // Increments nextLoanId 
        nextLoanId++;
    }

    // Function to fund a loan
    // Hint: Write the fundLoan function with necessary checks and logic
    function fundLoan (uint loanId) external payable loanExists(loanId) notFunded(loanId) {
        Loan storage loan = loans[loanId];
        // Checks if Loan amount is correct
        require(msg.value == loan.loanAmount, "Incorrect loan amount");
        // Loan status in now Funded
        loan.isFunded = true;
        loan.lender =msg.sender;
        payable(loan.borrower).transfer(loan.loanAmount);

        // Emits an event for Loan is Funded
        emit LoanFunded(loanId, msg.sender, loan.loanAmount);
    }
    // Function to repay a loan
    // Hint: Write the repayLoan function with necessary checks and logic
    function repayLoan(uint loanId) external payable loanExists(loanId){
         Loan storage loan = loans[loanId];
         // Checks if Loan is funded
         require(loan.isFunded, "Loan not funded");
         // Checks if Loan is repaid
         require(!loan.isRepaid, "Loan already repaid");
         // Checks if msg.sender is the Borrower of the Loan
         require(msg.sender == loan.borrower, "Only the borrower can repay loan");

          // Loan status must be paid first 
        uint repayAmount = loan.loanAmount + (loan.loanAmount * loan.interestRate/100);
        require(msg.value == repayAmount, "Incorrect repayment amount");
         // Loan status in now Repaid
        loan.isRepaid = true;
        payable(loan.lender).transfer(repayAmount);

        emit LoanRepaid(loanId, msg.sender, repayAmount);
    }

    // Function to claim collateral on default
    // Hint: Write the claimCollateral function with necessary checks and logic
    function claimCollateral(uint loanId) external loanExists(loanId){
         Loan storage loan = loans[loanId];
         // Checks if Loan is funded
         require(loan.isFunded, "Loan not funded");
         // Checks if Loan is repaid
         require(!loan.isRepaid, "Loan already repaid");
         // Checks the Timeframe of the loan
         require(block.timestamp > loan.dueDate, "Loan is not due yet");
         // Checks to see if Lender is claiming the Collateral
         require(msg.sender == loan.lender, "Only the lender can claim Collateral");


         uint collateralAmount = loan.collateralAmount;
         loan.collateralAmount = 0; // Avoid Rentrancy Attacks
         payable(loan.lender).transfer(collateralAmount);

         emit CollateralClaim(loanId, msg.sender, collateralAmount);
    }
}