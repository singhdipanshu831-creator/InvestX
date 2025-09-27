//comment 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract InvestXProject {
    struct InvestmentPool {
        address creator;
        string name;
        uint256 targetAmount;
        uint256 currentAmount;
        uint256 minInvestment;
        uint256 deadline;
        bool isActive;
        mapping(address => uint256) investments;
        address[] investors;
    }
    
    mapping(uint256 => InvestmentPool) public pools;
    uint256 public poolCounter;
    uint256 public platformFee = 250; // 2.5% in basis points
    address public owner;
    
    event PoolCreated(uint256 indexed poolId, address indexed creator, string name, uint256 targetAmount);
    event InvestmentMade(uint256 indexed poolId, address indexed investor, uint256 amount);
    event ReturnsDistributed(uint256 indexed poolId, uint256 totalReturns);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    // Core Function 1: Create Investment Pool
    function createPool(
        string memory _name,
        uint256 _targetAmount,
        uint256 _minInvestment,
        uint256 _durationDays
    ) external returns (uint256) {
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_minInvestment > 0, "Minimum investment must be greater than 0");
        require(_durationDays > 0, "Duration must be greater than 0");
        
        uint256 poolId = poolCounter++;
        InvestmentPool storage newPool = pools[poolId];
        
        newPool.creator = msg.sender;
        newPool.name = _name;
        newPool.targetAmount = _targetAmount;
        newPool.minInvestment = _minInvestment;
        newPool.deadline = block.timestamp + (_durationDays * 1 days);
        newPool.isActive = true;
        
        emit PoolCreated(poolId, msg.sender, _name, _targetAmount);
        return poolId;
    }
    
    // Core Function 2: Invest in Pool
    function investInPool(uint256 _poolId) external payable {
        InvestmentPool storage pool = pools[_poolId];
        
        require(pool.isActive, "Pool is not active");
        require(block.timestamp < pool.deadline, "Pool deadline has passed");
        require(msg.value >= pool.minInvestment, "Investment below minimum amount");
        require(pool.currentAmount + msg.value <= pool.targetAmount, "Investment exceeds target");
        
        if (pool.investments[msg.sender] == 0) {
            pool.investors.push(msg.sender);
        }
        
        pool.investments[msg.sender] += msg.value;
        pool.currentAmount += msg.value;
        
        emit InvestmentMade(_poolId, msg.sender, msg.value);
    }
    
    // Core Function 3: Distribute Returns
    function distributeReturns(uint256 _poolId) external payable onlyOwner {
        InvestmentPool storage pool = pools[_poolId];
        require(!pool.isActive, "Pool must be closed first");
        require(msg.value > 0, "Returns amount must be greater than 0");
        
        uint256 platformFeeAmount = (msg.value * platformFee) / 10000;
        uint256 distributionAmount = msg.value - platformFeeAmount;
        
        // Transfer platform fee to owner
        payable(owner).transfer(platformFeeAmount);
        
        // Distribute returns proportionally
        for (uint256 i = 0; i < pool.investors.length; i++) {
            address investor = pool.investors[i];
            uint256 investorShare = pool.investments[investor];
            uint256 returnAmount = (distributionAmount * investorShare) / pool.currentAmount;
            
            if (returnAmount > 0) {
                payable(investor).transfer(returnAmount);
            }
        }
        
        emit ReturnsDistributed(_poolId, msg.value);
    }
    
    // Helper Functions
    function closePool(uint256 _poolId) external {
        InvestmentPool storage pool = pools[_poolId];
        require(msg.sender == pool.creator || msg.sender == owner, "Unauthorized");
        require(block.timestamp >= pool.deadline || pool.currentAmount >= pool.targetAmount, "Cannot close pool yet");
        
        pool.isActive = false;
    }
    
    function getPoolInfo(uint256 _poolId) external view returns (
        address creator,
        string memory name,
        uint256 targetAmount,
        uint256 currentAmount,
        uint256 minInvestment,
        uint256 deadline,
        bool isActive
    ) {
        InvestmentPool storage pool = pools[_poolId];
        return (
            pool.creator,
            pool.name,
            pool.targetAmount,
            pool.currentAmount,
            pool.minInvestment,
            pool.deadline,
            pool.isActive
        );
    }
    
    function getInvestorBalance(uint256 _poolId, address _investor) external view returns (uint256) {
        return pools[_poolId].investments[_investor];
    }
}
