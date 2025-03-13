import { getContract, Network } from "./config";

export class VinceContracts {
    private network: Network;

    constructor(network: Network) {
        this.network = network;
    }

    async fetchDelegatedAgentPKPs(appId: number, version: number) {
        const contract = await getContract(this.network, 'AppView');
        const appView = await contract.getAppVersion(appId, version);
        return appView.delegatedAgentPkpTokenIds;
    }
    
}   