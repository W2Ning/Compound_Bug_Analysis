// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

contract StakingRewards {
    IERC20 public rewardsToken;
    IERC20 public stakingToken;


    // 奖励发放的速率
    uint public rewardRate = 100;
    
    // 上一次的更新时间
    uint public lastUpdateTime;

    // 当前池子中每个质押Token所获得的奖励 
    uint public rewardPerTokenStored;


    // 保存用户上一次与合约交互式时每个质押Token所获得的奖励
    mapping(address => uint) public userRewardPerTokenPaid;
    
    // 保存用户获得的奖励
    mapping(address => uint) public rewards;


    // 总供应量
    uint private _totalSupply;

    // 保存用户的质押的Token数量
    mapping(address => uint) private _balances;

    constructor(address _stakingToken, address _rewardsToken) {
        
        // 质押的Token
        stakingToken = IERC20(_stakingToken);
        
        // 奖励的Token
        rewardsToken = IERC20(_rewardsToken);
    }
    
    // 计算当前池子中每个质押Token所获得的奖励
    function rewardPerToken() public view returns (uint) {
        
        // 如果总供应量为0 则返回0
        if (_totalSupply == 0) {
            return 0;
        }

        // 当前池子中每个质押Token所获得的奖励 =  
        //                                   ((当前时间 - 上次更新时间) * 发放速率 / 总供应量) 
        //                                    + 
        //                                   上一次池子与任意用户交互时每个质押Token所获得的奖励
        return
            rewardPerTokenStored +
            (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / _totalSupply);
    }

    // 计算用户获得的奖励
    function earned(address account) public view returns (uint) {

        // 用户获得的奖励数量 = 用户的质押Token数量 
        //                     * 
        //                    (当前池子中每个质押Token所获得的奖励 - 用户上一次与池子交互时每个质押Token所获得的奖励)/10**18) 
        //                     + 
        //                    用户上一次与池子交互时获得的奖励
        return
            ((_balances[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    // 更新奖励发放比例
    modifier updateReward(address account) {

        // 更新当前每个Token该获得的奖励
        rewardPerTokenStored = rewardPerToken();

        // 记录时间戳
        lastUpdateTime = block.timestamp;

        // 记录用户获得的奖励
        rewards[account] = earned(account);

        // 把当前池子中每个质押Token所获得的奖励 记录在用户的mapping中
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    // 每次质押都会触发 updateReward() 
    function stake(uint _amount) external updateReward(msg.sender) {
        _totalSupply += _amount;
        _balances[msg.sender] += _amount;
        stakingToken.transferFrom(msg.sender, address(this), _amount);
    }

    // 每次提取质押Token 都会触发 updateReward()
    function withdraw(uint _amount) external updateReward(msg.sender) {
        _totalSupply -= _amount;
        _balances[msg.sender] -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    // 每次提取奖励 都会触发 updateReward()
    function getReward() external updateReward(msg.sender) {

        // 从mapping中获得用户得到的奖励 赋值给reward
        uint reward = rewards[msg.sender];

        // 把mapping中的用户奖励置零
        rewards[msg.sender] = 0;

        // 发放奖励
        rewardsToken.transfer(msg.sender, reward);
    }
}

// ERC20 接口
interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}
