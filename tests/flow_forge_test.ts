import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can create workflow template",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const approver = accounts.get('wallet_1')!;
    
    let states = [
      {
        state: types.ascii("DRAFT"),
        transitions: types.list([types.ascii("PENDING")]),
        approvers: types.list([types.principal(approver.address)])
      },
      {
        state: types.ascii("PENDING"),
        transitions: types.list([types.ascii("APPROVED"), types.ascii("REJECTED")]),
        approvers: types.list([types.principal(approver.address)])
      }
    ];
    
    let block = chain.mineBlock([
      Tx.contractCall('flow_forge', 'create-template', [
        types.ascii("Purchase Order Template"),
        types.ascii("DRAFT"),
        types.list(states)
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk();
    assertEquals(block.receipts[0].result, types.ok(types.uint(1)));
  }
});

Clarinet.test({
  name: "Can create workflow from template",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const approver = accounts.get('wallet_1')!;
    
    // Create template
    let states = [
      {
        state: types.ascii("DRAFT"),
        transitions: types.list([types.ascii("PENDING")]),
        approvers: types.list([types.principal(approver.address)])
      }
    ];
    
    let block = chain.mineBlock([
      Tx.contractCall('flow_forge', 'create-template', [
        types.ascii("Purchase Order Template"),
        types.ascii("DRAFT"),
        types.list(states)
      ], deployer.address)
    ]);
    
    // Create workflow from template
    block = chain.mineBlock([
      Tx.contractCall('flow_forge', 'create-workflow-from-template', [
        types.ascii("Purchase Order #1"),
        types.uint(1)
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    // Verify initial state
    block = chain.mineBlock([
      Tx.contractCall('flow_forge', 'get-workflow-state', [
        types.uint(1)
      ], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.ascii("DRAFT"));
  }
});

Clarinet.test({
  name: "Can create new workflow",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('flow_forge', 'create-workflow', [
        types.ascii("Purchase Order"),
        types.ascii("DRAFT")
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk();
    assertEquals(block.receipts[0].result, types.ok(types.uint(1)));
  }
});

Clarinet.test({
  name: "Can define and execute workflow transitions",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const approver = accounts.get('wallet_1')!;
    
    // Create workflow
    let block = chain.mineBlock([
      Tx.contractCall('flow_forge', 'create-workflow', [
        types.ascii("Purchase Order"),
        types.ascii("DRAFT")
      ], deployer.address)
    ]);
    
    // Define transitions
    let transitions = [types.ascii("PENDING"), types.ascii("APPROVED"), types.ascii("REJECTED")];
    let approvers = [types.principal(approver.address)];
    
    block = chain.mineBlock([
      Tx.contractCall('flow_forge', 'define-state-transitions', [
        types.uint(1),
        types.ascii("DRAFT"), 
        types.list(transitions),
        types.list(approvers)
      ], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    // Execute transition
    block = chain.mineBlock([
      Tx.contractCall('flow_forge', 'transition-workflow', [
        types.uint(1),
        types.ascii("PENDING")
      ], approver.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    // Verify state
    block = chain.mineBlock([
      Tx.contractCall('flow_forge', 'get-workflow-state', [
        types.uint(1)
      ], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result, types.ascii("PENDING"));
  }
});

Clarinet.test({
  name: "Cannot transition to invalid state",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const approver = accounts.get('wallet_1')!;
    
    // Create and setup workflow
    let block = chain.mineBlock([
      Tx.contractCall('flow_forge', 'create-workflow', [
        types.ascii("Purchase Order"),
        types.ascii("DRAFT")
      ], deployer.address),
      
      Tx.contractCall('flow_forge', 'define-state-transitions', [
        types.uint(1),
        types.ascii("DRAFT"),
        types.list([types.ascii("PENDING")]),
        types.list([types.principal(approver.address)])
      ], deployer.address)
    ]);
    
    // Try invalid transition
    block = chain.mineBlock([
      Tx.contractCall('flow_forge', 'transition-workflow', [
        types.uint(1),
        types.ascii("APPROVED")
      ], approver.address)
    ]);
    
    block.receipts[0].result.expectErr(types.uint(102)); // err-invalid-state
  }
});
