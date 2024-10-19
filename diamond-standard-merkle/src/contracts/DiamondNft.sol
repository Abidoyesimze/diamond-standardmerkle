// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibDiamond } from "./libraries/LibDiamond.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";  


library LibNFTStorage {
    bytes32 constant STORAGE_POSITION = keccak256("diamond.nft.storage");
    
    struct NFTStorage {
        string name;
        string symbol;
        mapping(uint256 => address) owners;
        mapping(address => uint256) balances;
        mapping(uint256 => address) tokenApprovals;
        mapping(address => mapping(address => bool)) operatorApprovals;
        uint256 totalSupply;
        uint256 currentTokenId;
        
        // Merkle storage
        bytes32 merkleRoot;
        mapping(address => bool) hasClaimed;
        
        // Presale storage
        uint256 presalePrice; // Price in wei
        bool presaleActive;
        uint256 maxPerWallet;
    }
    
    function diamondStorage() internal pure returns (NFTStorage storage ds) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}


contract ERC721Facet {
    LibNFTStorage.NFTStorage internal s;
    
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    
    function initialize(string memory _name, string memory _symbol) external {
        LibDiamond.enforceIsContractOwner();
        s = LibNFTStorage.diamondStorage();
        s.name = _name;
        s.symbol = _symbol;
    }
    
    function name() external view returns (string memory) {
        return s.name;
    }
    
    function symbol() external view returns (string memory) {
        return s.symbol;
    }
    
    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "ERC721: invalid owner");
        return s.balances[owner];
    }
    
    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = s.owners[tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }
    
    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), "ERC721: mint to zero address");
        require(s.owners[tokenId] == address(0), "ERC721: token already minted");
        
        s.balances[to] += 1;
        s.owners[tokenId] = to;
        s.totalSupply += 1;
        
        emit Transfer(address(0), to, tokenId);
    }
}


contract MerkleFacet {
    LibNFTStorage.NFTStorage internal s;
    
    event Claimed(address indexed claimer, uint256 tokenId);
    
    function setMerkleRoot(bytes32 _merkleRoot) external {
        LibDiamond.enforceIsContractOwner();
        s = LibNFTStorage.diamondStorage();
        s.merkleRoot = _merkleRoot;
    }
    
    function claim(bytes32[] calldata merkleProof) external {
        s = LibNFTStorage.diamondStorage();
        require(!s.hasClaimed[msg.sender], "Already claimed");
        
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(merkleProof, s.merkleRoot, leaf), "Invalid proof");
        
        s.hasClaimed[msg.sender] = true;
        uint256 tokenId = s.currentTokenId + 1;
        s.currentTokenId = tokenId;
        
        ERC721Facet(address(this))._mint(msg.sender, tokenId);
        
        emit Claimed(msg.sender, tokenId);
    }
}


contract PresaleFacet is ReentrancyGuard {
    LibNFTStorage.NFTStorage internal s;
    
    event PresaleStarted(uint256 price);
    event PresaleEnded();
    event TokensPurchased(address indexed buyer, uint256 amount);
    
    function startPresale(uint256 _maxPerWallet) external {
        LibDiamond.enforceIsContractOwner();
        s = LibNFTStorage.diamondStorage();
        s.presaleActive = true;
        s.presalePrice = 0.01 ether;  // 1 ETH = 30 NFTs, so 0.01 ETH minimum
        s.maxPerWallet = _maxPerWallet;
        emit PresaleStarted(s.presalePrice);
    }
    
    function endPresale() external {
        LibDiamond.enforceIsContractOwner();
        s = LibNFTStorage.diamondStorage();
        s.presaleActive = false;
        emit PresaleEnded();
    }
    
    function buyTokens() external payable nonReentrant {
        s = LibNFTStorage.diamondStorage();
        require(s.presaleActive, "Presale not active");
        require(msg.value >= 0.01 ether, "Minimum 0.01 ETH required");
        
        uint256 tokenAmount = (msg.value * 30) / 1 ether;  // 1 ETH = 30 NFTs
        require(s.balances[msg.sender] + tokenAmount <= s.maxPerWallet, "Exceeds max per wallet");
        
        for(uint256 i = 0; i < tokenAmount; i++) {
            uint256 tokenId = s.currentTokenId + 1;
            s.currentTokenId = tokenId;
            ERC721Facet(address(this))._mint(msg.sender, tokenId);
        }
        
        emit TokensPurchased(msg.sender, tokenAmount);
    }
}