import Foundation
import DataSourcerer
import ReactiveSwift

extension Resource where Value: Decodable, Failure == APIError {
    static func loadURLRequest(
        _ urlRequest: URLRequest
    ) -> SignalProducer<Value, Resource.FailureType> {
        SignalProducer { observer, lifetime in
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)

            let task = session.dataTask(with: urlRequest) { data, _, error in

                guard error == nil else {
                    observer.send(
                        error: .unknown(
                        """
                        Request could not be loaded -
                        we are too lazy to parse the actual error yet ;)
                        """
                        )
                    )
                    return
                }

                // make sure we got data
                guard let responseData = data else {
                    observer.send(
                        error: .unknown("responseData is nil")
                    )
                    return
                }

                do {
                    let value = try JSONDecoder().decode(Value.self, from: responseData)
                    observer.send(value: value)
                    observer.sendCompleted()
                } catch {
                    observer.send(
                        error: .unknown(
                            """
                            Value cannot be parsed: \(String(describing: error))
                            """
                        )
                    )
                    return
                }
            }
            task.resume()
        }

    }
}
