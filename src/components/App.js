import React, { Component } from 'react';
import Web3 from 'web3'
import EscrowExchange from '../abis/EscrowExchange.json'
import EscrowFactory from '../abis/EscrowFactory.json'
import AdminEscrowActions from '../abis/AdminEscrowActions.json'
import Navbar from './Navbar'
import Main from './Main'

class App extends Component {

  async componentWillMount() {
    await this.loadWeb3()
    await this.loadBlockchainData()
  }

  async loadWeb3() {
    if (window.ethereum) {
      window.web3 = new Web3(window.ethereum)
      await window.ethereum.enable()
    }
    else if (window.web3) {
      window.web3 = new Web3(window.web3.currentProvider)
    }
    else {
      window.alert('Non-Ethereum browser detected. You should consider trying MetaMask!')
    }
  }

  async loadBlockchainData() {
    const web3 = window.web3
    // Load account
    const accounts = await web3.eth.getAccounts()
    this.setState({ account: accounts[0] })
    const networkId = await web3.eth.net.getId()
    const EscrowExchangeNetworkData = EscrowExchange.networks[networkId]
    const AdminEscrowActionNetworkData = AdminEscrowActions.networks[networkId]
    if(EscrowExchangeNetworkData) {
      const escrowExchange = new web3.eth.Contract(EscrowExchange.abi, EscrowExchangeNetworkData.address)
      const adminEscrowActions = new web3.eth.Contract(AdminEscrowActions.abi, AdminEscrowActionNetworkData.address)
      this.setState({ escrowExchange, adminEscrowActions })
      const contractCount = await escrowExchange.methods.getContractCountForCurrentUser().call({from: this.state.account})
      this.setState({ contractCount })
      // Load Contracts FOR CURRENT USER
      for (var i = 0; i < contractCount; i++) {
        var contractDetails = await escrowExchange.methods.getContractForCurrentUser(i).call({from: this.state.account})
        var contract = new web3.eth.Contract(EscrowFactory.abi, contractDetails[11])
        var buyerDepositCheck = await contract.methods.getIfAddressDeposited(contractDetails[1]).call({ from: this.state.account })
        var sellerDepositCheck = await contract.methods.getIfAddressDeposited(contractDetails[2]).call({ from: this.state.account })
        var contractCompleted = await contract.methods.getContractComplete().call({ from: this.state.account })
        var isAdmin = await adminEscrowActions.methods.getAdmin(this.state.account).call({from: this.state.account})
        Object.assign(contractDetails, {12: sellerDepositCheck, 13: buyerDepositCheck, 14: contractCompleted, 15: isAdmin})
        this.setState({
          contracts: [...this.state.contracts, contract],
          contractDetails: [...this.state.contractDetails, contractDetails]
        })
      }
      this.setState({ loading: false})
    } else {
      window.alert('Escrow and EscrowExchange contracts not deployed to detected network.')
    }
  }

  constructor(props) {
    super(props)
    this.state = {
      account: '',
      buyer:'',
      contracts: [],
      contractDetails: [],
      seller: '',
      amount: 0,
      deposit: 0,
      loading: true
    }

    this.addContractAddressToRegistry = this.addContractAddressToRegistry.bind(this)
    this.buyerDeposit = this.buyerDeposit.bind(this)
    this.sellerDeposit = this.sellerDeposit.bind(this)
    this.reverseBuyerDeposit = this.reverseBuyerDeposit.bind(this)
    this.reverseSellerDeposit = this.reverseSellerDeposit.bind(this)
    this.claimDeposits = this.claimDeposits.bind(this)
    this.sendAmount = this.sendAmount.bind(this)
    this.paySeller = this.paySeller.bind(this)
    this.refundBuyer = this.refundBuyer.bind(this)
    this.requestAdminAction = this.requestAdminAction.bind(this)
    this.createContract = this.createContract.bind(this)
    this.adminContractTakeAction = this.adminContractTakeAction.bind(this)
  }

  // EscrowExchange Calls

  addContractAddressToRegistry(buyerAddress, sellerAddress, contractAddress) {
    this.setState({ loading: true })
    this.state.escrowExchange.methods.addContractAddressToRegistry(buyerAddress, sellerAddress, contractAddress)
    .once('receipt', (receipt) => {
      this.setState({ loading: false })
    })
  }

  // Binary_action is a 0,1 which represents refund_buyer, pay_seller
  adminContractTakeAction(index, binary_action, address) {
    this.setState({ loading: true })
    this.state.adminEscrowActions.methods.adminContractTakeAction(index, binary_action, address).send({ from: this.state.account})
    .once('receipt', (receipt) => {
      this.setState({ loading: false })
    })
  }

  // Escrow Calls

  createContract(buyer, seller, amount, deposit, notes) {
    this.setState({ loading: true })
    this.state.escrowExchange.methods.createContract(buyer, seller, amount, deposit, notes).send({ from: this.state.account})
    .once('receipt', (receipt) => {
      this.setState({ loading: false })
      window.location.reload()
    })
  }

  buyerDeposit(contract, deposit) {
    this.setState({ loading: true })
    contract.methods.buyerDeposit().send({ from: this.state.account, value: deposit })
    .once('receipt', (receipt) => {
      this.setState({ loading: false })
      window.location.reload()
    })
  }

  sellerDeposit(contract, deposit){
    this.setState({ loading: true })
    contract.methods.sellerDeposit().send({ from: this.state.account, value: deposit })
    .once('receipt', (receipt) => {
      this.setState({ loading: false })
      window.location.reload()
    })
  }

  reverseBuyerDeposit(contract) {
    this.setState({ loading: true })
    contract.methods.reverseBuyerDeposit().send({ from: this.state.account })
    .once('receipt', (receipt) => {
      this.setState({ loading: false })
      window.location.reload()
    })
  }

  reverseSellerDeposit(contract) {
    this.setState({ loading: true })
    contract.methods.reverseSellerDeposit().send({ from: this.state.account })
    .once('receipt', (receipt) => {
      this.setState({ loading: false })
      window.location.reload()
    })
  }

  claimDeposits(contract) {
    this.setState({ loading: true })
    contract.methods.claimDeposits().send({ from: this.state.account })
    .once('receipt', (receipt) => {
      this.setState({ loading: false })
      window.location.reload()
    })
  }

  sendAmount(contract, amount) {
    this.setState({ loading: true })
    contract.methods.sendAmount().send({ from: this.state.account, value: amount })
    .once('receipt', (receipt) => {
      this.setState({ loading: false })
      window.location.reload()
    })
  }

  paySeller(contract) {
    this.setState({ loading: true })
    contract.methods.paySeller().send({ from: this.state.account })
    .once('receipt', (receipt) => {
      this.setState({ loading: false })
      window.location.reload()
    })
  }

  refundBuyer(contract) {
    this.setState({ loading: true })
    contract.methods.refundBuyer().send({ from: this.state.account })
    .once('receipt', (receipt) => {
      this.setState({ loading: false })
      window.location.reload()
    })
  }

  requestAdminAction(contract, notes) {
    this.setState({ loading: true })
    contract.methods.requestAdminAction(notes).send({ from: this.state.account })
    .once('receipt', (receipt) => {
      this.setState({ loading: false })
      window.location.reload()
    })
  }

  render() {
    return (
      <div>
        <Navbar account={this.state.account} />
        <div className="container-fluid mt-5">
          <div className="row">
            <main role="main" className="col-lg-12 d-flex">
              { this.state.loading
                ? <div id="loader" className="text-center"><p className="text-center">Loading...</p></div>
                : <Main
                  createContract={this.createContract}
                  buyerDeposit={this.buyerDeposit}
                  sellerDeposit={this.sellerDeposit}
                  reverseBuyerDeposit={this.reverseBuyerDeposit}
                  reverseSellerDeposit={this.reverseSellerDeposit}
                  claimDeposits={this.claimDeposits}
                  sendAmount={this.sendAmount}
                  paySeller={this.paySeller}
                  refundBuyer={this.refundBuyer}
                  requestAdminAction={this.requestAdminAction}
                  adminContractTakeAction={this.adminContractTakeAction}
                  myContractsDetails={this.state.contractDetails}
                  contractObjects={this.state.contracts}
                  account={this.state.account}
                  />
              }
            </main>
          </div>
        </div>
      </div>
    );
  }
}

export default App;