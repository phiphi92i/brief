//
//  ContactsManager.swift
//  brief.brief
//
//  Created by Philippe Tchinda on 02/05/2024.
//

import Contacts
import Firebase

class ContactsManager: ObservableObject {
    @Published var contacts: [String: Bool] = [:] // [phoneNumber: true]
    private var db = Firestore.firestore()
    private var contactNames: [String: String] = [:] // [phoneNumber: name]


    func fetchAndSendContactsIfNeeded() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("User is not authenticated.")
            return
        }

        let contactListRef = db.collection("contactLists").document(userID)

        contactListRef.getDocument { documentSnapshot, error in
            if let error = error {
                print("Error checking contact list in Firebase: \(error)")
            } else {
                if documentSnapshot?.exists == false {
                    // Send the contact list to Firebase only if it doesn't exist
                    self.fetchContacts()
                } else {
                    print("User already has a contact list registered.")
                }
            }
        }
    }

    
    
    
    func fetchContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            if granted {
                DispatchQueue.global().async {
                    self.fetchContactsInBackground(store)
                    UserDefaults.standard.set(true, forKey: "hasLoggedInBefore")
                }
            }
        }
    }

    private func fetchContactsInBackground(_ store: CNContactStore) {
        let keys = [CNContactPhoneNumbersKey, CNContactGivenNameKey, CNContactFamilyNameKey]
        let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])

        do {
            try store.enumerateContacts(with: request) { contact, stop in
                let phoneNumbers = contact.phoneNumbers.compactMap { phoneData in
                    return phoneData.value.stringValue
                }

                let formattedPhoneNumbers = phoneNumbers.compactMap { normalizePhoneNumber($0) }
                let name = "\(contact.givenName) \(contact.familyName)"

                for number in formattedPhoneNumbers {
                    DispatchQueue.main.async {
                        
                        self.contacts[number] = true // Set the value to true or () if using [String: Void]
                        self.contactNames[number] = name
                        print("Fetched contact: \(number)")
                    }

                }

            }

            // Check if the user already has a contact list registered before sending it to Firebase
            checkAndSendContactListToFirebase()
        } catch {
            print("Error fetching contacts: \(error)")
        }
    }

    private func checkAndSendContactListToFirebase() {
        guard let userID = Auth.auth().currentUser?.uid else {
            return
        }

        let contactListRef = db.collection("contactLists").document(userID)

        contactListRef.getDocument { documentSnapshot, error in
            if let error = error {
                print("Error checking contact list in Firebase: \(error)")
            } else {
                if documentSnapshot?.exists == false {
                    // Send the contact list to Firebase only if it doesn't exist
                    self.sendContactListToFirebase()
                } else {
                    print("User already has a contact list registered.")
                }
            }
        }
    }


    private func sendContactListToFirebase() {
        guard let userID = Auth.auth().currentUser?.uid else {
            return
        }

        let contactListRef = db.collection("contactLists").document(userID)
        let contactList = Array(contacts.keys)
        print("Sending contact list to Firebase: \(contactList)")

        contactListRef.setData(["phoneNumbers": contactList]) { error in
            if let error = error {
                print("Error sending contact list to Firebase: \(error)")
            } else {
                print("Contact list sent to Firebase successfully.")
            }
        }
    }

    private func normalizePhoneNumber(_ phoneNumber: String) -> String? {
        let countryCode = getCountryCode()

        if phoneNumber.isEmpty {
            return ""
        }
        let firstPhoneChar = String(phoneNumber[phoneNumber.index(phoneNumber.startIndex, offsetBy: 0)])
        if firstPhoneChar == "+" {
            return phoneNumber.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        } else {
            var newPhoneNumber = phoneNumber
            if firstPhoneChar == "0" {
                newPhoneNumber = String(phoneNumber.dropFirst())
            }
            newPhoneNumber = "+\(countryCode)\(newPhoneNumber)"
            return newPhoneNumber.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        }
    }
    
    func getCountryCode() -> String {
        let countryCode = CNContactsUserDefaults.shared().countryCode.uppercased()
        let prefixCodes = ["AF": "93", "AE": "971", "AL": "355", "AN": "599", "AS":"1", "AD": "376", "AO": "244", "AI": "1", "AG":"1", "AR": "54","AM": "374", "AW": "297", "AU":"61", "AT": "43","AZ": "994", "BS": "1", "BH":"973", "BF": "226","BI": "257", "BD": "880", "BB": "1", "BY": "375", "BE":"32","BZ": "501", "BJ": "229", "BM": "1", "BT":"975", "BA": "387", "BW": "267", "BR": "55", "BG": "359", "BO": "591", "BL": "590", "BN": "673", "CC": "61", "CD":"243","CI": "225", "KH":"855", "CM": "237", "CA": "1", "CV": "238", "KY":"345", "CF":"236", "CH": "41", "CL": "56", "CN":"86","CX": "61", "CO": "57", "KM": "269", "CG":"242", "CK": "682", "CR": "506", "CU":"53", "CY":"537","CZ": "420", "DE": "49", "DK": "45", "DJ":"253", "DM": "1", "DO": "1", "DZ": "213", "EC": "593", "EG":"20", "ER": "291", "EE":"372","ES": "34", "ET": "251", "FM": "691", "FK": "500", "FO": "298", "FJ": "679", "FI":"358", "FR": "33", "GB":"44", "GF": "594", "GA":"241", "GS": "500", "GM":"220", "GE":"995","GH":"233", "GI": "350", "GQ": "240", "GR": "30", "GG": "44", "GL": "299", "GD":"1", "GP": "590", "GU": "1", "GT": "502", "GN":"224","GW": "245", "GY": "595", "HT": "509", "HR": "385", "HN":"504", "HU": "36", "HK": "852", "IR": "98", "IM": "44", "IL": "972", "IO":"246", "IS": "354", "IN": "91", "ID":"62", "IQ":"964", "IE": "353","IT":"39", "JM":"1", "JP": "81", "JO": "962", "JE":"44", "KP": "850", "KR": "82","KZ":"77", "KE": "254", "KI": "686", "KW": "965", "KG":"996","KN":"1", "LC": "1", "LV": "371", "LB": "961", "LK":"94", "LS": "266", "LR":"231", "LI": "423", "LT": "370", "LU": "352", "LA": "856", "LY":"218", "MO": "853", "MK": "389", "MG":"261", "MW": "265", "MY": "60","MV": "960", "ML":"223", "MT": "356", "MH": "692", "MQ": "596", "MR":"222", "MU": "230", "MX": "52","MC": "377", "MN": "976", "ME": "382", "MP": "1", "MS": "1", "MA":"212", "MM": "95", "MF": "590", "MD":"373", "MZ": "258", "NA":"264", "NR":"674", "NP":"977", "NL": "31","NC": "687", "NZ":"64", "NI": "505", "NE": "227", "NG": "234", "NU":"683", "NF": "672", "NO": "47","OM": "968", "PK": "92", "PM": "508", "PW": "680", "PF": "689", "PA": "507", "PG":"675", "PY": "595", "PE": "51", "PH": "63", "PL":"48", "PN": "872","PT": "351", "PR": "1","PS": "970", "QA": "974", "RO":"40", "RE":"262", "RS": "381", "RU": "7", "RW": "250", "SM": "378", "SA":"966", "SN": "221", "SC": "248", "SL":"232","SG": "65", "SK": "421", "SI": "386", "SB":"677", "SH": "290", "SD": "249", "SR": "597","SZ": "268", "SE":"46", "SV": "503", "ST": "239","SO": "252", "SJ": "47", "SY":"963", "TW": "886", "TZ": "255", "TL": "670", "TD": "235", "TJ": "992", "TH": "66", "TG":"228", "TK": "690", "TO": "676", "TT": "1", "TN":"216","TR": "90", "TM": "993", "TC": "1", "TV":"688", "UG": "256", "UA": "380", "US": "1", "UY": "598","UZ": "998", "VA":"379", "VE":"58", "VN": "84", "VG": "1", "VI": "1","VC":"1", "VU":"678", "WS": "685", "WF": "681", "YE": "967", "YT": "262","ZA": "27" , "ZM": "260", "ZW":"263"]
        let countryDialingCode = prefixCodes[countryCode.uppercased()] ?? "1"
        return countryDialingCode
    }

    func getContactNameForNumber(_ phoneNumber: String) -> String? {
        return contactNames[phoneNumber]
    }
}
