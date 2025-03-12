import { LIT_NETWORKS_KEYS } from '@lit-protocol/types';
import { ethers } from 'ethers';
import { PKPEthersWallet } from '@lit-protocol/pkp-ethers';
import { DelegateeSigs, fetchDelegatedAgentPKPs, setDelegateeWallet, updateDelegateeWallet } from '../pkp';
import { createPKPSigner, createPKPSignedJWT, verifyJWTSignature } from '../auth';
import { IStorage, Storage } from '../auth';

export interface VincentSDKConfig {
  storage?: IStorage;
  consentPageUrl?: string;
  network?: LIT_NETWORKS_KEYS;
}

export class VincentSDK {
  private storage: Storage;
  private consentPageUrl: string;
  private network: LIT_NETWORKS_KEYS;

  constructor(config: VincentSDKConfig = {}) {
    this.storage = new Storage(config.storage);
    this.consentPageUrl = config.consentPageUrl || 'https://demo.vincent.com';
    this.network = config.network || 'datil';
  }

  // JWT Management
  async createSigner(pkpWallet: PKPEthersWallet): Promise<any> {
    return createPKPSigner(pkpWallet);
  }

  async createSignedJWT(
    pkpWallet: PKPEthersWallet,
    pkp: any,
    payload: Record<string, any>,
    expiresInMinutes: number = 10,
    audience: string | string[]
  ): Promise<string> {
    this.clearJWT();
    const jwt = await createPKPSignedJWT(pkpWallet, pkp, payload, expiresInMinutes, audience);
    this.storeJWT(jwt);
    return jwt;
  }

  async verifyJWT(publicKey: string): Promise<boolean> {
    const jwt = await this.getJWT();
    if (!jwt) {
      throw new Error('No JWT found');
    }
    return verifyJWTSignature(jwt, publicKey);
  }

  // Storage Management
  async storeJWT(jwt: string): Promise<void> {
    await this.storage.storeJWT(jwt);
  }

  async getJWT(): Promise<string | null> {
    return this.storage.getJWT();
  }

  async clearJWT(): Promise<void> {
    await this.storage.clearJWT();
  }

  async clearAll(): Promise<void> {
    await this.storage.clearAll();
  }

  // Lit Action Invocation for App Owner through Delegatee Wallet
  async invokeLitAction(signer: ethers.Signer, litActionCID: string, params: any) {
    const sessionSigs = new DelegateeSigs(this.network);
    return sessionSigs.invokeLitAction(signer, litActionCID, params);
  }

  // Agent PKP Management
  async getDelegatedAgentPKPs(): Promise<void> {
    const pkps = await fetchDelegatedAgentPKPs();
    return pkps;
  }

  async setDelegatee(walletAddress: string): Promise<void> {
    const txn = await setDelegateeWallet();
    return txn;
  }

  async updateDelegatee(walletAddress: string): Promise<void> {
    const txn = await updateDelegateeWallet();
    return txn;
  }

  // Consent Page Management
  openSignInConsentPage(): void {
    const url = new URL('/signin', this.consentPageUrl);
    window.open(url.toString(), '_blank');
  }

  openDelegationControlConsentPage(): void {
    const url = new URL('/delegate', this.consentPageUrl);
    window.open(url.toString(), '_blank');
  }
}
