//
//  InviteContactView.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 10/02/2024.
//

import Foundation
import Contacts
import MessageUI
import Combine
import Firebase
import FirebaseFunctions
import libPhoneNumber
import PhoneNumberKit


class InviteContactViewModel: ObservableObject {
    @Published var contacts: [String: [Contact]] = [:]
    private let functions = Functions.functions()
    @Published var contactsOnApp: [UserData] = []
    @Published var isLoadingContactsOnApp = false
    @Published var currentContacts: [Contact] =     []
    @Published var profileViewModels: [String: ProfileViewModel] = [:]
    
    

    init() {
        requestAccess()
    }
    
    
    
    func fetchPhoneFriends() {
        isLoadingContactsOnApp = true
        let countryCode = getCountryCode()
        
        // Flatten the contacts and normalize their phone numbers
        let allPhoneNumbers: [String] = contacts.flatMap { $0.value }
            .compactMap { contact in
                normalizePhoneNumber(phoneNumber: contact.number, expectedCountryCallingCode: countryCode)
            }
            .filter { !$0.isEmpty }
        
        // Call the Cloud Function to fetch friends based on phone numbers
        functions.httpsCallable("getPhoneFriends").call(["phoneNumbers": allPhoneNumbers]) { [weak self] result, error in
            guard let self = self else { return }

            DispatchQueue.main.async { self.isLoadingContactsOnApp = false }
            
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            
            guard let data = result?.data as? [String: Any],
                  let usersArray = data["users"] as? [[String: Any]] else {
                print("Data formatting error or 'users' key not found.")
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: usersArray)
                let decodedUsers = try JSONDecoder().decode([UserData].self, from: jsonData)
                
                // Deduplicate based on id
                let uniqueUsers = Array(Dictionary(grouping: decodedUsers, by: { $0.id }).values.compactMap(\.first))
                
                DispatchQueue.main.async {
                    self.contactsOnApp = uniqueUsers
                }
            } catch {
                print("Decoding error: \(error.localizedDescription)")
            }
        }
    }

    
    
    func getProfileViewModel(for userId: String) -> ProfileViewModel {
        if let viewModel = profileViewModels[userId] {
            return viewModel
        } else {
            let newViewModel = ProfileViewModel(userID: userId)
            profileViewModels[userId] = newViewModel
            return newViewModel
        }
    }

    func removeProfileViewModel(for userId: String) {
        profileViewModels[userId] = nil
    }
    
    
    
    
    
  /*  private func setupContactsChangeListener() {
        // Setup logic here...
        // Example using NotificationCenter
        print("did setup")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contactsDidChange),
            name: NSNotification.Name.CNContactStoreDidChange,
            object: nil
        )
    }
    
    @objc private func contactsDidChange(notification: Notification) {
        print("CALLED contactsDidChange")
        fetchContacts()
    }
   */
    
    func getCountryCode() -> String {
        let countryCode = CNContactsUserDefaults.shared().countryCode.uppercased()
        let prefixCodes = ["AF": "93", "AE": "971", "AL": "355", "AN": "599", "AS":"1", "AD": "376", "AO": "244", "AI": "1", "AG":"1", "AR": "54","AM": "374", "AW": "297", "AU":"61", "AT": "43","AZ": "994", "BS": "1", "BH":"973", "BF": "226","BI": "257", "BD": "880", "BB": "1", "BY": "375", "BE":"32","BZ": "501", "BJ": "229", "BM": "1", "BT":"975", "BA": "387", "BW": "267", "BR": "55", "BG": "359", "BO": "591", "BL": "590", "BN": "673", "CC": "61", "CD":"243","CI": "225", "KH":"855", "CM": "237", "CA": "1", "CV": "238", "KY":"345", "CF":"236", "CH": "41", "CL": "56", "CN":"86","CX": "61", "CO": "57", "KM": "269", "CG":"242", "CK": "682", "CR": "506", "CU":"53", "CY":"537","CZ": "420", "DE": "49", "DK": "45", "DJ":"253", "DM": "1", "DO": "1", "DZ": "213", "EC": "593", "EG":"20", "ER": "291", "EE":"372","ES": "34", "ET": "251", "FM": "691", "FK": "500", "FO": "298", "FJ": "679", "FI":"358", "FR": "33", "GB":"44", "GF": "594", "GA":"241", "GS": "500", "GM":"220", "GE":"995","GH":"233", "GI": "350", "GQ": "240", "GR": "30", "GG": "44", "GL": "299", "GD":"1", "GP": "590", "GU": "1", "GT": "502", "GN":"224","GW": "245", "GY": "595", "HT": "509", "HR": "385", "HN":"504", "HU": "36", "HK": "852", "IR": "98", "IM": "44", "IL": "972", "IO":"246", "IS": "354", "IN": "91", "ID":"62", "IQ":"964", "IE": "353","IT":"39", "JM":"1", "JP": "81", "JO": "962", "JE":"44", "KP": "850", "KR": "82","KZ":"77", "KE": "254", "KI": "686", "KW": "965", "KG":"996","KN":"1", "LC": "1", "LV": "371", "LB": "961", "LK":"94", "LS": "266", "LR":"231", "LI": "423", "LT": "370", "LU": "352", "LA": "856", "LY":"218", "MO": "853", "MK": "389", "MG":"261", "MW": "265", "MY": "60","MV": "960", "ML":"223", "MT": "356", "MH": "692", "MQ": "596", "MR":"222", "MU": "230", "MX": "52","MC": "377", "MN": "976", "ME": "382", "MP": "1", "MS": "1", "MA":"212", "MM": "95", "MF": "590", "MD":"373", "MZ": "258", "NA":"264", "NR":"674", "NP":"977", "NL": "31","NC": "687", "NZ":"64", "NI": "505", "NE": "227", "NG": "234", "NU":"683", "NF": "672", "NO": "47","OM": "968", "PK": "92", "PM": "508", "PW": "680", "PF": "689", "PA": "507", "PG":"675", "PY": "595", "PE": "51", "PH": "63", "PL":"48", "PN": "872","PT": "351", "PR": "1","PS": "970", "QA": "974", "RO":"40", "RE":"262", "RS": "381", "RU": "7", "RW": "250", "SM": "378", "SA":"966", "SN": "221", "SC": "248", "SL":"232","SG": "65", "SK": "421", "SI": "386", "SB":"677", "SH": "290", "SD": "249", "SR": "597","SZ": "268", "SE":"46", "SV": "503", "ST": "239","SO": "252", "SJ": "47", "SY":"963", "TW": "886", "TZ": "255", "TL": "670", "TD": "235", "TJ": "992", "TH": "66", "TG":"228", "TK": "690", "TO": "676", "TT": "1", "TN":"216","TR": "90", "TM": "993", "TC": "1", "TV":"688", "UG": "256", "UA": "380", "US": "1", "UY": "598","UZ": "998", "VA":"379", "VE":"58", "VN": "84", "VG": "1", "VI": "1","VC":"1", "VU":"678", "WS": "685", "WF": "681", "YE": "967", "YT": "262","ZA": "27" , "ZM": "260", "ZW":"263"]
        let countryDialingCode = prefixCodes[countryCode.uppercased()] ?? "1"
        return countryDialingCode
    }
    
    func requestAccess() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            if granted {
                DispatchQueue.global().async {
                    self.fetchContacts()
                }
            }
        }
    }
    
    func fetchContacts() {
        DispatchQueue.global(qos: .userInitiated).async {
            let store = CNContactStore()
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactImageDataKey]
            let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])
            var fetchedContacts: [String: [Contact]] = [:]
            var nonAlphabeticalContacts: [Contact] = []
            var totalContacts = 0  // Variable to hold the total number of contacts
            
            do {
                try store.enumerateContacts(with: request) { (contact, stop) in
                    let name = "\(contact.givenName) \(contact.familyName)"
                    let number = contact.phoneNumbers.first?.value.stringValue ?? ""
                    let image = contact.imageData != nil ? UIImage(data: contact.imageData!) : nil
                    let contactItem = Contact(id: UUID(), name: name, number: number, image: image)
                    let firstLetter = String(name.prefix(1)).uppercased()
                    
                    if firstLetter == "A" {
                        fetchedContacts[firstLetter, default: []].append(contactItem)
                    } else if firstLetter.range(of: "[A-Za-z]", options: .regularExpression) != nil {
                        fetchedContacts[firstLetter, default: []].append(contactItem)
                    } else {
                        nonAlphabeticalContacts.append(contactItem)
                    }
                    
                    totalContacts += 1  // Increment the total number of contacts
                }
            } catch {
                print("Failed to fetch contacts:", error)
            }
            
            // Log the total number of contacts
            Analytics.logEvent("total_contacts_fetched", parameters: [
                "total_count": totalContacts
            ])
            
            // Sort the contacts within each group
            for (key, value) in fetchedContacts {
                fetchedContacts[key] = value.sorted(by: { $0.name < $1.name })
            }
            
            // Add non-alphabetical contacts at the end
            fetchedContacts["#"] = nonAlphabeticalContacts.sorted(by: { $0.name < $1.name })
            
            DispatchQueue.main.async {
                self.contacts = fetchedContacts
                self.fetchPhoneFriends()
            }
            
//            self.setupContactsChangeListener()
        }
    }
    
    
    func inviteContact(phoneNumber: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("Unable to fetch current user's ID")
            return
        }
        
        // Normalize the phone number to E.164 format
        guard let normalizedPhoneNumber = normalizePhoneNumber(phoneNumber: phoneNumber, expectedCountryCallingCode: getCountryCode()) else {
            print("Error normalizing phone number")
            return
        }
        
        // Save the invitation in Firestore
        let db = Firestore.firestore()
        let invitationRef = db.collection("invitations").document(normalizedPhoneNumber)
        
        invitationRef.setData(["inviterUserId": currentUserID]) { error in
            if let error = error {
                print("Error saving invitation: \(error.localizedDescription)")
            } else {
                print("Invitation saved successfully.")
            }
        }
    }
        
    
    
    func normalizePhoneNumber(phoneNumber: String, expectedCountryCallingCode: String) -> String? {
        if phoneNumber.isEmpty {
            return ""
        }
        let firstPhoneChar = String(phoneNumber[phoneNumber.index(phoneNumber.startIndex, offsetBy: 0)])
        if firstPhoneChar == "+" {
            return phoneNumber.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        } else {
            var newPhoneNumber = phoneNumber
            if (firstPhoneChar == "0") {
                newPhoneNumber = String(phoneNumber.dropFirst())
            }
            newPhoneNumber = "+\(expectedCountryCallingCode)\(newPhoneNumber)";
            return newPhoneNumber.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        }
    }
}
    




struct UserData: Codable, Identifiable, Hashable {
    let id: String
    let phoneNumber: String
    let profileImageUrl: String?
    let username: String

    enum CodingKeys: String, CodingKey {
        case id, phoneNumber, profileImageUrl, username
    }
}
