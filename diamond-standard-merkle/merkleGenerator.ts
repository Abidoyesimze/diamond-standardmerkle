import { MerkleTree } from 'merkletreejs';
import keccak256 from 'keccak256';
import * as fs from 'fs';


function generateMerkleTree(addresses: string[]) {
    
    const leaves = addresses.map(addr => keccak256(addr));
    
    
    const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    const root = tree.getRoot().toString('hex');
    
    
    const proofs: { [key: string]: string[] } = {};
    addresses.forEach(addr => {
        const leaf = keccak256(addr);
        const proof = tree.getProof(leaf).map(x => '0x' + x.data.toString('hex'));
        proofs[addr] = proof;
    });
    
    
    const output = {
        root: '0x' + root,
        proofs: proofs
    };
    
    
    fs.writeFileSync('merkle_data.json', JSON.stringify(output, null, 2));
    console.log('Merkle root:', output.root);
    console.log('Merkle data saved to merkle_data.json');
    
    return output;
}


const whitelist = [
    "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
    "0x90F79bf6EB2c4f870365E785982E1f101E93b906"
];


generateMerkleTree(whitelist);