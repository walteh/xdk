import JavaScriptCore
import XDK

// extension String {
// 	func getTheServices() -> [String] {
// 		return loadTheServices()
// 	}
// }

public func loadTheServices() -> [String] {
	let context = JSContext()

	context?.evaluateScript(jsSource)

	context?.evaluateScript("""
	function getAvailableServices() {
	    // Create an instance of the ARN class to access the _linkTemplates method
	    const arnInstance = new ARN('arn:aws:service:region:account:resource');
	    const linkTemplates = arnInstance._getLinkTemplates();
	    // Extract the keys from the linkTemplates object
	    const services = Object.keys(linkTemplates);
	    return services;
	}
	""")

	// _getLinkTemplates
	// let arn2: JSValue? = context?.objectForKeyedSubscript("ARNz")
	// let arn3 = arn2?.call(withArguments: [])
	let dat = context?.objectForKeyedSubscript("getAvailableServices")

	let d2: JSValue? = dat?.call(withArguments: [])
	let d3 = d2?.toArray()
	// XDK.Log(.info).send("d2 \(d3)")

	var servicesArray = [String]()

	for service in d3! {
		servicesArray.append("\(service)")
	}
	return servicesArray
}

public let regions = [
	"af-south-1": "Africa (Cape Town)",
	"ap-east-1": "Asia Pacific (Hong Kong)",
	"ap-northeast-1": "Asia Pacific (Tokyo)",
	"ap-northeast-2": "Asia Pacific (Seoul)",
	"ap-northeast-3": "Asia Pacific (Osaka)",
	"ap-south-1": "Asia Pacific (Mumbai)",
	"ap-south-2": "Asia Pacific (Hyderabad)",
	"ap-southeast-1": "Asia Pacific (Singapore)",
	"ap-southeast-2": "Asia Pacific (Sydney)",
	"ap-southeast-3": "Asia Pacific (Jakarta)",
	"ap-southeast-4": "Asia Pacific (Melbourne)",
	"ca-central-1": "Canada (Central)",
	"ca-west-1": "Canada West (Calgary)",
	"eu-central-1": "Europe (Frankfurt)",
	"eu-central-2": "Europe (Zurich)",
	"eu-north-1": "Europe (Stockholm)",
	"eu-south-1": "Europe (Milan)",
	"eu-south-2": "Europe (Milan)",
	"eu-west-1": "Europe (Ireland)",
	"eu-west-2": "Europe (London)",
	"eu-west-3": "Europe (Paris)",
	"il-central-1": "Israel (Tel Aviv)",
	"me-central-1": "Middle East (UAE)",
	"me-south-1": "Middle East (Bahrain)",
	"sa-east-1": "South America (Sao Paulo)",
	"us-east-1": "US East (N. Virginia)",
	"us-east-2": "US East (Ohio)",
	"us-west-1": "US West (N. California)",
	"us-west-2": "US West (Oregon)",
	"cn-north-1": "China (Beijing)",
	"cn-northwest-1": "China (Ningxia)",
	"us-gov-east-1": "AWS GovCloud (US-East)",
	"us-gov-west-1": "AWS GovCloud (US-West)",
]


public let regionsList = regions.keys.sorted() as [String]
