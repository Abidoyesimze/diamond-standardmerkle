// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/contracts/DiamondNft.sol";

contract DiamondNFTTest is Test {
    Diamond diamond;
    ERC721Facet erc721Facet;
    MerkleFacet merkleFacet;
    PresaleFacet presaleFacet;
    
    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);
    
    bytes32 merkleRoot;
    mapping(address => bytes32[]) merkleProofs;
    
    function setUp() public {
        
        erc721Facet = new ERC721Facet();
        merkleFacet = new MerkleFacet();
        presaleFacet = new PresaleFacet();
        
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);
        
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(erc721Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC721Facet")
        });
        
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(merkleFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("MerkleFacet")
        });
        
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(presaleFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("PresaleFacet")
        });
        
        
        diamond = new Diamond(owner, address(this), cut);
        
        ERC721Facet(address(diamond)).initialize("DiamondNFT", "DNFT");
        
        string memory root = vm.readLine("merkle_data.json");
        merkleRoot = bytes32(vm.parseJson(root, ".root"));
        MerkleFacet(address(diamond)).setMerkleRoot(merkleRoot);
        
        string memory proof1 = vm.readLine("merkle_data.json");
        merkleProofs[user1] = abi.decode(vm.parseJson(proof1, string(abi.encodePacked(".proofs.", Strings.toHexString(user1)))), (bytes32[]));
    }
    
    function testPresale() public {
        PresaleFacet(address(diamond)).startPresale(5);
        
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        PresaleFacet(address(diamond)).buyTokens{value: 0.1 ether}();
        
        
        assertEq(ERC721Facet(address(diamond)).balanceOf(user1), 3);
    }
    
    function testMerkleClaim() public {
        vm.prank(user1);
        MerkleFacet(address(diamond)).claim(merkleProofs[user1]);
        
        
        assertEq(ERC721Facet(address(diamond)).balanceOf(user1), 1);
    }
    
    function testFailInvalidMerkleProof() public {
        
        vm.prank(user2);
        MerkleFacet(address(diamond)).claim(merkleProofs[user1]);
    }
    
    // Helper function to generate function selectors (implementation needed)
    function generateSelectors(string memory _facetName) internal pure returns (bytes4[] memory selectors) {
    
    }
}