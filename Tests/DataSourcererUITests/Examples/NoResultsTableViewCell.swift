import DataSourcerer
import Foundation
import UIKit

public class NoResultsTableViewCell : UITableViewCell {

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        commonInit()
    }

    public init() {
        super.init(style: .default, reuseIdentifier: nil)
        commonInit()
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("NoResultsTableViewCell cannot be used from a storyboard")
    }

    public func commonInit() {
        textLabel?.text = "No results found"
    }
}
