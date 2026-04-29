import Contacts
import Foundation

let args = CommandLine.arguments
guard args.count >= 4 else {
    print("Usage: add-contact <firstName> <lastName> <phone> [email]")
    exit(1)
}

let firstName = args[1]
let lastName = args[2]
let phone = args[3]
let email = args.count > 4 ? args[4] : ""

let contact = CNMutableContact()
contact.givenName = firstName
contact.familyName = lastName
contact.phoneNumbers = [CNLabeledValue(
    label: CNLabelPhoneNumberMobile,
    value: CNPhoneNumber(stringValue: phone))]

if !email.isEmpty {
    contact.emailAddresses = [CNLabeledValue(
        label: CNLabelWork,
        value: email as NSString)]
}

let store = CNContactStore()
let request = CNSaveRequest()
request.add(contact, toContainerWithIdentifier: nil)

do {
    try store.execute(request)
    print("Contact created successfully")
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}