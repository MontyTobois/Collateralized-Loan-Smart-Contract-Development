// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Collateralized Loan Contract
contract CollateralizedLoan {
    // Define the structure of a loan
    struct Loan {
        address borrower;
        // Hint: Add a field for the lender's address
        address lender;
        uint collateralAmount;
        // Hint: Add fields for loan amount, interest rate, due date, isFunded, isRepaid
        uint loanAmount;
        uint interestRate; //Interest rate in percentages 
        uint dueDate; // Timestamp when the loan is due
        bool isFunded;
        bool isRepaid;
        
    }

    // Create a mapping to manage the loans
    mapping(uint => Loan) public loans;
    uint public nextLoanId;

    // Hint: Define events for loan requested, funded, repaid, and collateral claimed
    event LoanRequested(uint loanId, address borrower, uint collateralAmount, uint loanAmount, uint interestRate, uint dueDate);
    event LoanFunded(uint loanId, address borrower, uint loanAmount);
    event LoanRepaid(uint loanId, address lender, uint loanAmount);

    // Custom Modifiers
    // Hint: Write a modifier to check if a loan exists
    modifier loanExists(uint loanId) {
        require(loanId < nextLoanId, "Loan does not exist.");
        _;
    }
    // Hint: Write a modifier to ensure a loan is not already funded
    modifier notFunded(uint loanId) {
        require(!loans[loanId].isFunded, "Loan is funded already.");
        _;
    }

    // Function to deposit collateral and request a loan
    function depositCollateralAndRequestLoan(uint _interestRate, uint _duration) external payable {
        // Hint: Check if the collateral is more than 0
        require(msg.value > 0, "collateral amount must be greater the 0");
        // Hint: Calculate the loan amount based on the collateralized amount
        uint loanAmount = msg.value * 2;
        uint dueDate = block.timestamp + _duration;
        // Hint: Increment nextLoanId and create a new loan in the loans mapping
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
        // Hint: Emit an event for loan request
        emit LoanRequested(nextLoanId, msg.sender, msg.value, loanAmount, _interestRate, dueDate);
        nextLoanId++;
    }

    // Function to fund a loan
    // Hint: Write the fundLoan function with necessary checks and logic
    function fundLoan (uint loanId) external payable loanExists(loanId) notFunded(loanId) {
        Loan storage loan = loans[loanId];
        require(msg.value == loan.loanAmount, "Incorrect loan amount");

        loan.isFunded = true;
        loan.lender =msg.sender;
        payable(loan.borrower).transfer(loan.loanAmount);

        emit LoanFunded(loanId, msg.sender, loan.loanAmount);
    }
    // Function to repay a loan
    // Hint: Write the repayLoan function with necessary checks and logic
    function repayLoan(uint loanId) external payable loanExists(loanId){
         Loan storage loan = loans[loanId];
         require(loan.isFunded, "Loan not funded");
         require(!loan.isRepaid, "Loan already repaid");
         require(msg.sender == loan.borrower, "Only the borrower can repay loan");

         // checks if loan is repaid
        uint repayAmount = loan.loanAmount + (loan.loanAmount * loan.interestRate/100);
        require(msg.value == repayAmount, "Incorrect repayment amount");

        loan.isRepaid = true;
        payable(loan.lender).transfer(repayAmount);

        emit LoanRepaid(loanId, msg.sender, repayAmount);
    }

    // Function to claim collateral on default
    // Hint: Write the claimCollateral function with necessary checks and logic
}