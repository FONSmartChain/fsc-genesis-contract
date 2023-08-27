pragma solidity 0.6.4;
pragma experimental ABIEncoderV2;

import "./lib/SafeMath.sol";
contract Vote {
  using SafeMath for uint256;

  // Info of each node.
  struct NodeInfo {
    address owner; // node owner
    string name;
    string url;
    uint256 index;
    uint256 rank;
    uint256 totalStaked;
    bool isActive;
  }

  // Info of each node.
  NodeInfo[] public nodeInfo;
  // sorted id
  uint256[] public ranking;

  uint256 public constant MAX = ~uint256(0);

  // Info of each user that stakes node tokens.
  mapping(uint256 => mapping(address => uint256)) public userVotes;
  // user deposited index
  mapping(address => uint256[]) public userDepositedIndex;
  // user deposited
  mapping(address => mapping(uint256 => bool)) private userDeposited;
  // Duplicate node check
  mapping(address => bool) public nodeAdded;
  // use address find node id
  mapping(address => uint256) public nodeIndexFromOwner;

  event Reg(address indexed user, string name, string url);
  event Update(address indexed user, string name, string url);
  event Close(address indexed user);

  event Deposit(address indexed user, uint256 id, uint256 amount);
  event Withdraw(address indexed user, uint256 id, uint256 amount);
  event CheckPoint(uint256 id, uint256 amount);

  modifier validateNodeByPid(uint256 _id) {
    require(_id < nodeInfo.length, 'Node does not exist');
    _;
  }

  function getNodeIndexFromAddress() internal view returns (uint256) {
    require(nodeAdded[msg.sender], 'Node does not exist');
    return nodeIndexFromOwner[msg.sender];
  }

  function isActiveNode(address owner) public view returns (bool) {
    if (!nodeAdded[owner]) return false;
    return nodeInfo[nodeIndexFromOwner[owner]].isActive;
  }

  // reg a new node need 9999 FON
  function reg(string calldata name, string calldata url) external payable {
    address owner = msg.sender;
    require(!nodeAdded[owner], 'duplicate node');
    require(msg.sender != address(0x29F31A69a450d9f0022dc410A2d48291D6a38244), 'genesis node');
    require(msg.value == 9999 * 1e18);
    nodeAdded[owner] = true;
    uint256 index = nodeInfo.length;
    nodeInfo.push(
      NodeInfo({
        owner: owner,
        name: name,
        url: url,
        isActive: true,
        totalStaked: 0,
        rank: MAX,
        index: index
      })
    );
    nodeIndexFromOwner[owner] = index;
    emit Reg(owner, name, url);
  }

  // unreg node
  function unreg() public {
    NodeInfo storage node = nodeInfo[getNodeIndexFromAddress()];
    require(node.isActive, 'not active');
    require(node.owner == msg.sender, 'only owner');
    payable(msg.sender).transfer(9999 * 1e18);
    node.isActive = false;
    rankDel(node.rank);
    emit Close(msg.sender);
  }

  // Update the node info.
  function update(string memory name, string memory url) public {
    NodeInfo storage node = nodeInfo[getNodeIndexFromAddress()];
    require(node.isActive, 'not active');
    require(node.owner == msg.sender, 'only owner');
    node.name = name;
    node.url = url;
    emit Update(msg.sender, name, url);
  }

  function rankUp(uint256 index) internal {
    // index 0 is the top
    if (index == 0) return;
    NodeInfo storage cur = nodeInfo[ranking[index]];
    NodeInfo storage upperNode = nodeInfo[ranking[index - 1]];
    while (upperNode.totalStaked < cur.totalStaked) {
      ranking[index] = upperNode.index;
      upperNode.rank = index;
      ranking[index - 1] = cur.index;
      cur.rank = index - 1;
      --index;
      if (index == 0) break;
      upperNode = nodeInfo[ranking[index - 1]];
    }
  }

  function rankDown(uint256 index) internal {
    if (index == MAX) return;
    // if index is the bottom reurn;
    uint256 max = ranking.length - 1;
    if (index >= max) return;
    NodeInfo storage cur = nodeInfo[ranking[index]];
    NodeInfo storage lowerNode = nodeInfo[ranking[index + 1]];
    while (lowerNode.totalStaked > cur.totalStaked) {
      ranking[index] = lowerNode.index;
      lowerNode.rank = index;
      ranking[index + 1] = cur.index;
      cur.rank = index + 1;
      ++index;
      if (index == max) break;
      lowerNode = nodeInfo[ranking[index + 1]];
    }
  }

  function rankDel(uint256 index) internal {
    if (index == MAX) return;
    nodeInfo[ranking[index]].rank = MAX;
    for (uint256 i = index; i < ranking.length - 1; ++i) {
      ranking[i] = ranking[i + 1];
      nodeInfo[ranking[i]].rank = i;
    }
    ranking.pop();
  }

  function deposit(uint256 _nid) external payable validateNodeByPid(_nid) {
    uint256 _amount = msg.value;
    NodeInfo storage node = nodeInfo[_nid];
    if (_amount > 0) {
      require(node.isActive, 'node now is not active');
      if (!userDeposited[msg.sender][_nid]) {
        userDeposited[msg.sender][_nid] = true;
        userDepositedIndex[msg.sender].push(_nid);
      }
      userVotes[_nid][msg.sender] = userVotes[_nid][msg.sender].add(_amount);
      if (node.totalStaked == 0) {
        require(ranking.length <= 99, 'slot is full');
        node.rank = ranking.length;
        ranking.push(node.index);
      }
      node.totalStaked = node.totalStaked.add(_amount);
      rankUp(node.rank);
      emit Deposit(msg.sender, _nid, _amount);
      emit CheckPoint(_nid, node.totalStaked);
    }
  }

  function withdraw(uint256 _nid, uint256 _amount) public validateNodeByPid(_nid) {
    NodeInfo storage node = nodeInfo[_nid];
    require(_amount > 0, "amount is zero");
    require(userVotes[_nid][msg.sender] >= _amount, 'withdraw: not good');
    userVotes[_nid][msg.sender] = userVotes[_nid][msg.sender].sub(_amount);
    payable(msg.sender).transfer(_amount);
    node.totalStaked = node.totalStaked.sub(_amount);
    if (node.totalStaked == 0) {
      rankDel(node.rank);
    } else rankDown(node.rank);
    emit Withdraw(msg.sender, _nid, _amount);
    emit CheckPoint(_nid, node.totalStaked);
  }

  function nodeLength() external view returns (uint256) {
    return nodeInfo.length;
  }

  function rankLength() external view returns (uint256) {
    return ranking.length;
  }

  function userDepositedCount(address user) external view returns (uint256) {
    return userDepositedIndex[user].length;
  }

  function userPage(address user, uint256 start)
    external
    view
    returns (uint256 count, uint256[2][50] memory result)
  {
    uint256 length = userDepositedIndex[user].length;
    if (start > length) count = 0;
    else count = (length >= start + 50) ? 50 : length - start;
    for (uint256 i = 0; i < count; ++i) {
      uint256 nid = userDepositedIndex[user][i + start];
      result[i][0] = nid;
      result[i][1] = userVotes[nid][user];
    }
  }
  function activeNode()
    external
    view
    returns (uint256 count, address[20] memory result)
  {
    uint256 length = ranking.length;
    count = (length > 20) ? 20 : length;
    for (uint256 i = 0; i < count; ++i) {
      result[i] = nodeInfo[ranking[i]].owner;
    }
  }

  function rankPage(uint256 start)
    external
    view
    returns (uint256 count, NodeInfo[50] memory result)
  {
    uint256 length = ranking.length;
    if (start > length) count = 0;
    else count = (length >= start + 50) ? 50 : length - start;
    for (uint256 i = 0; i < count; ++i) {
      result[i] = nodeInfo[ranking[i + start]];
    }
  }
}
