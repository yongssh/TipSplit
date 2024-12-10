//
//  ContentView.swift
//  TipSplit
//
//  Created by Yong-Yu Huang on 10/12/2024.
//

import SwiftUI

struct AppColors {
    
    //https://www.color-hex.com/color-palette/1053554
    
    // #FF4040
    static let red = Color(red: 255/255, green: 64/255, blue: 64/255)
    // #F7E256
    static let yellow = Color(red: 247/255, green: 226/255, blue: 86/255)
    // #FFE8EE
    static let pink = Color(red: 255/255, green: 232/255, blue: 238/255)
    // #89A7D5
    static let blue = Color(red: 137/255, green: 167/255, blue: 213/255)
    // #453256
    static let purple = Color(red: 69/255, green: 50/255, blue: 86/255)
}

// TRANSACTION STRUCT
struct Transaction: Identifiable {
    let id: UUID
    let description: String
    let bill: Double
    let tip: Int
    let people: Int
    let amountPerPerson: Double
}


// Two tabs: calculator and history
struct ContentView: View {
    var body: some View {
        TabView {
            MainView()
                .tabItem {
                    Label("Calculator", systemImage: "dollarsign.circle")
                }
            
            TransactionHistoryView()
                .tabItem {
                    Label("History", systemImage: "list.bullet")
                }
        }
        .accentColor(AppColors.red)
    }
}

// main calculator + form view
struct MainView: View {
    @State private var billAmount: String = ""
    @State private var tipPercentage: Double = 15
    @State private var numberOfPeople: Int = 1
    @State private var venmoUsernames: String = ""
    @State private var transactionDescription: String = ""
    
    @StateObject private var transactionStore = TransactionStore.shared

    private var totalTip: Double {
        guard let amount = Double(billAmount) else { return 0 }
        return amount * tipPercentage / 100
    }
    
    private var totalBill: Double {
        guard let amount = Double(billAmount) else { return 0 }
        return amount + totalTip
    }
    
    private var amountPerPerson: Double {
        if numberOfPeople > 0 {
            return totalBill / Double(numberOfPeople)
        }
        return totalBill
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Enter Details").customSectionHeader()) {
                        TextField("Enter bill amount", text: $billAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(StyledTextField())
                        VStack {
                            Text("Tip Percentage: \(Int(tipPercentage))%")
                                .font(.headline)
                                .foregroundColor(AppColors.purple)
                            Slider(value: $tipPercentage, in: 0...100, step: 1)
                                .accentColor(AppColors.red)
                        }
                        Stepper("Split between \(numberOfPeople) people", value: $numberOfPeople, in: 1...20)
                            .font(.headline)
                            .foregroundColor(AppColors.purple)
                        TextField("Venmo usernames (comma-separated)", text: $venmoUsernames)
                            .textFieldStyle(StyledTextField())
                        TextField("What's this for?", text: $transactionDescription)
                            .textFieldStyle(StyledTextField())
                    }
                    
                    Section(header: Text("Results").customSectionHeader()) {
                        HStack {
                            Text("Total Tip:")
                            Spacer()
                            Text("$\(totalTip, specifier: "%.2f")")
                        }
                        .customResultRow()
                        HStack {
                            Text("Total Bill:")
                            Spacer()
                            Text("$\(totalBill, specifier: "%.2f")")
                        }
                        .customResultRow()
                        HStack {
                            Text("Amount Per Person:")
                            Spacer()
                            Text("$\(amountPerPerson, specifier: "%.2f")")
                        }
                        .customResultRow()
                    }
                    
                    Section {
                        Button(action: addToHistory) {
                            Text("Add Split to History")
                                .buttonStyle()
                        }
                        .disabled(billAmount.isEmpty || transactionDescription.isEmpty || Double(billAmount) == nil)
                        
                        Button(action: sendVenmoRequest) {
                            Text("Send Venmo Request")
                                .buttonStyle()
                        }
                        .disabled(venmoUsernames.isEmpty || Double(billAmount) == nil)
                    }
                }
                .background(AppColors.blue)
            }
            .navigationTitle("TipSplit")
            .background(AppColors.pink.ignoresSafeArea())
        }
    }
    
    // add funciton to history
    func addToHistory() {
        guard let bill = Double(billAmount) else { return }
        let transaction = Transaction(
            id: UUID(),
            description: transactionDescription,
            bill: bill,
            tip: Int(tipPercentage),
            people: numberOfPeople,
            amountPerPerson: amountPerPerson
        )
        transactionStore.addTransaction(transaction)
        clearInputs()
    }
    func sendVenmoRequest() {
        guard let amount = Double(billAmount) else {
            print("Invalid bill amount.")
            return
        }
        
        // format amount into string (%.2f)
        let formattedAmount = String(format: "%.2f", amount / Double(numberOfPeople))
        let usernames = venmoUsernames.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let note = transactionDescription.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // construct venmo URL (check if deeplinks still work? they disabled their developer API) https://www.reddit.com/r/venmo/comments/1bfvx71/anyone_else_notice_that_venmo_deep_links_are_no/
        
        let venmoURLString = "https://account.venmo.com/pay?audience=private&amount=\(formattedAmount)&note=\(note)&recipients=%2C\(usernames)&txn=pay"
        
        // check and open URL
        if let venmoURL = URL(string: venmoURLString), UIApplication.shared.canOpenURL(venmoURL) {
            UIApplication.shared.open(venmoURL)
            print("Opening Venmo with URL: \(venmoURL.absoluteString)")
        } else {
            print("Unable to open Venmo URL or Venmo is not installed.")
        }
    }

    
    // clear inputs for new entry
    func clearInputs() {
        billAmount = ""
        venmoUsernames = ""
        transactionDescription = ""
    }
}

struct TransactionHistoryView: View {
    @StateObject private var transactionStore = TransactionStore.shared

    var body: some View {
        NavigationView {
            VStack {
                if transactionStore.transactions.isEmpty {
                    Text("No transactions yet!")
                        .foregroundColor(Color.white)
                } else {
                    List {
                        ForEach(transactionStore.transactions) { transaction in
                            VStack(alignment: .leading) {
                                Text("\(transaction.description) - \(transaction.people) people")
                                    .font(.headline)
                                    .foregroundColor(AppColors.red)
                                Text("Bill: $\(transaction.bill, specifier: "%.2f") | Tip: \(transaction.tip)%")
                                    .foregroundColor(AppColors.purple)
                                Text("$\(transaction.amountPerPerson, specifier: "%.2f")/person")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Transaction History")
            .background(AppColors.pink.ignoresSafeArea())
        }
    }
}

// Custom Styles
extension View {
    func buttonStyle() -> some View {
        self.font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppColors.purple)
            .cornerRadius(10)
    }

    func customSectionHeader() -> some View {
        self.font(.headline)
            .foregroundColor(AppColors.purple)
    }
    
    func customResultRow() -> some View {
        self.font(.subheadline)
            .foregroundColor(AppColors.purple)
    }
}

struct StyledTextField: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(10)
            .background(AppColors.pink.opacity(0.3))
            .cornerRadius(8)
            .font(.subheadline)
    }
}

class TransactionStore: ObservableObject {
    static let shared = TransactionStore()
    @Published private(set) var transactions: [Transaction] = []

    func addTransaction(_ transaction: Transaction) {
        transactions.insert(transaction, at: 0)
    }
}

