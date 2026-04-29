import Contacts
import Foundation

var args = Array(CommandLine.arguments.dropFirst())
var resultPath: String?

if let resultIndex = args.firstIndex(of: "--result"), resultIndex + 1 < args.count {
    resultPath = args[resultIndex + 1]
    args.removeSubrange(resultIndex...resultIndex + 1)
}

func finish(success: Bool, message: String? = nil, error: String? = nil) -> Never {
    var payload: [String: Any] = ["success": success]
    if let message {
        payload["message"] = message
        print(message)
    }
    if let error {
        payload["error"] = error
        print("Error: \(error)")
    }

    if let resultPath,
       let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
       let json = String(data: data, encoding: .utf8) {
        try? json.write(toFile: resultPath, atomically: true, encoding: .utf8)
    }

    exit(success ? 0 : 1)
}

guard args.count >= 3 else {
    print("Usage: add-contact <firstName> <lastName> <phone> [email]")
    finish(success: false, error: "Usage: add-contact <firstName> <lastName> <phone> [email]")
}

let firstName = args[0]
let lastName = args[1]
let phone = args[2]
let email = args.count > 3 ? args[3] : ""

let store = CNContactStore()
let semaphore = DispatchSemaphore(value: 0)
var accessGranted = false
var accessError: Error?

store.requestAccess(for: .contacts) { granted, error in
    accessGranted = granted
    accessError = error
    semaphore.signal()
}
semaphore.wait()

if !accessGranted {
    finish(success: false, error: "Contacts access denied. \(accessError?.localizedDescription ?? "")")
}

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

let request = CNSaveRequest()
request.add(contact, toContainerWithIdentifier: nil)

do {
    try store.execute(request)
    finish(success: true, message: "Contact created successfully")
} catch {
    finish(success: false, error: error.localizedDescription)
}