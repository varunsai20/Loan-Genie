//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

contract LoanGenie {
    enum TxnType {
        Lend,
        Borrow
    }

    struct Transaction {
        uint256 txnId;
        address payable customer;
        uint256 value;
        TxnType txnType;
        uint256 timeStamp;
        uint256 interest;
        uint256 timePeriod;
        bool closed;
    }

    uint256 txnNo;
    uint8 lendRate;
    uint8 borrowRate;
    address payable admin;
    mapping(address => mapping(uint256 => Transaction)) public transactions;
    mapping(address => uint256[]) userTxns;
    uint256 adminEarnings;

    event lend(Transaction);
    event borrow(Transaction);
    event withdrawn(Transaction);
    event paid(Transaction);

    constructor(uint8 Lrate, uint8 Brate) payable {
        lendRate = Lrate;
        borrowRate = Brate;
        adminEarnings = 0;
        txnNo = 0;
        adminEarnings = 0;
        admin = payable(msg.sender);
    }

    modifier notAdmin() {
        require(admin != msg.sender, "Admin can't perform this operation");
        _;
    }

    modifier onlyAdmin() {
        require(admin == msg.sender, "Admin acess required");
        _;
    }

    function lendFn() public payable notAdmin {
        require(msg.value > 0, "Invest some money beetch");
        Transaction memory _txn;
        txnNo++;
        _txn = Transaction(
            txnNo,
            payable(msg.sender),
            msg.value,
            TxnType.Lend,
            block.timestamp,
            0,
            0,
            false
        );
        transactions[msg.sender][txnNo] = _txn;
        userTxns[msg.sender].push(txnNo);
        emit lend(_txn);
    }

    function borrowFn(uint256 _value) public notAdmin {
        require(address(this).balance > _value, "Insufficient Funds");
        Transaction memory _txn;
        txnNo++;
        _txn = Transaction(
            txnNo,
            payable(msg.sender),
            _value,
            TxnType.Borrow,
            block.timestamp,
            0,
            0,
            false
        );
        transactions[msg.sender][txnNo] = _txn;
        _txn.customer.transfer(_txn.value);
        userTxns[msg.sender].push(txnNo);
        emit borrow(_txn);
    }

    function getTransactions() public view returns (Transaction[] memory) {
        Transaction[] memory _txns = new Transaction[](
            userTxns[msg.sender].length
        );
        for (uint256 i = 0; i < _txns.length; i++) {
            _txns[i] = transactions[msg.sender][userTxns[msg.sender][i]];
        }
        return _txns;
    }

    function withdraw(uint256 _txnId) public {
        require(
            transactions[msg.sender][_txnId].txnId == _txnId,
            "Invalid Transaction"
        );
        require(
            transactions[msg.sender][_txnId].txnType == TxnType.Lend,
            "Invalid Transaction"
        );
        require(
            transactions[msg.sender][_txnId].closed == false,
            "Money already withdrawn"
        );
        uint256 _time;
        uint256 _i;
        (_i, _time) = calcLendInterest(
            transactions[msg.sender][_txnId].value,
            transactions[msg.sender][_txnId].timeStamp
        );
        require(
            address(this).balance >=
                (transactions[msg.sender][_txnId].value + _i),
            "Insufficient funds in Contract, Try again Later"
        );
        require(_time >= 7, "Money cannot be withdrawn in 7days");
        transactions[msg.sender][_txnId].interest = _i;
        transactions[msg.sender][_txnId].timePeriod = _time;
        transactions[msg.sender][_txnId].customer.transfer(
            transactions[msg.sender][_txnId].value +
                transactions[msg.sender][_txnId].interest
        );
        adminEarnings -= _i;
        emit withdrawn(transactions[msg.sender][_txnId]);
    }

    function pay(uint256 _txnId) public payable {
        require(
            transactions[msg.sender][_txnId].txnId == _txnId,
            "Invalid Transaction"
        );
        require(
            transactions[msg.sender][_txnId].txnType == TxnType.Borrow,
            "Invalid Transaction"
        );
        require(
            transactions[msg.sender][_txnId].closed == false,
            "Money already Paid"
        );
        require(msg.value > 0, "Send some money beetch");
        uint256 _time;
        uint256 _i;
        (_i, _time) = calcBorrowInterest(
            transactions[msg.sender][_txnId].value,
            transactions[msg.sender][_txnId].timeStamp
        );
        require(
            msg.value == (transactions[msg.sender][_txnId].value + _i),
            "Value sent not equal Loan amount"
        );
        transactions[msg.sender][_txnId].interest = _i;
        transactions[msg.sender][_txnId].timePeriod = _time;
        transactions[msg.sender][_txnId].closed = true;
        adminEarnings += _i;
        emit paid(transactions[msg.sender][_txnId]);
    }

    function calcLendInterest(uint256 p, uint256 t)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 time = (block.timestamp - t) / 86400; // Converting Unix timestamp into days.
        uint256 i = (p * time * lendRate) / 1000;
        return (i, time);
    }

    function calcBorrowInterest(uint256 p, uint256 t)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 time = (block.timestamp - t) / 86400; // Converting Unix timestamp into days.
        uint256 i = (p * time * borrowRate) / 1000;
        return (i, time);
    }

    function getPayAmount(uint256 _txnId)
        public
        view
        returns (uint256, uint256)
    {
        uint256 _i;
        uint256 _time;
        require(
            transactions[msg.sender][_txnId].txnId == _txnId,
            "Invalid Transaction"
        );
        require(
            transactions[msg.sender][_txnId].closed == false,
            "Money already Paid"
        );
        (_i, _time) = calcBorrowInterest(
            transactions[msg.sender][_txnId].value,
            transactions[msg.sender][_txnId].timeStamp
        );
        return (_i + transactions[msg.sender][_txnId].value, _time);
    }

    function getWithdrawAmount(uint256 _txnId)
        public
        view
        returns (uint256, uint256)
    {
        uint256 _i;
        uint256 _time;
        require(
            transactions[msg.sender][_txnId].txnId == _txnId,
            "Invalid Transaction"
        );
        require(
            transactions[msg.sender][_txnId].closed == false,
            "Money already Paid"
        );
        (_i, _time) = calcLendInterest(
            transactions[msg.sender][_txnId].value,
            transactions[msg.sender][_txnId].timeStamp
        );
        return (_i + transactions[msg.sender][_txnId].value, _time);
    }

    function adminWithdrawProfits() public onlyAdmin {
        admin.transfer(adminEarnings);
    }

    function getBalance() public view onlyAdmin returns (uint256) {
        return (address(this).balance);
    }

    function addMoneyToContract() public payable onlyAdmin {
        require(msg.value > 0, "Invest some money beetch");
    }
}
