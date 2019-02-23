import Foundation
import UIKit

public class IdiomaticErrorTableViewCell : UITableViewCell {

    public var content: StateErrorMessage = .default {
        didSet {
            refreshContent()
        }
    }

    public var defaultErrorMessage: String {
        return NSLocalizedString("""
                                 An error occurrec while loading.\n
                                 Please try again!
                                 """, comment: "")
    }

    public lazy var label: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
        label.textColor = .gray
        label.textAlignment = .center
        label.numberOfLines = 0

        self.contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 20).isActive = true
        label.leftAnchor.constraint(equalTo: self.contentView.leftAnchor, constant: 20).isActive = true
        label.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -20).isActive = true
        label.rightAnchor.constraint(equalTo: self.contentView.rightAnchor, constant: -20).isActive = true
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true

        return label
    }()

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
        fatalError("IdiomaticErrorTableViewCell cannot be used from a storyboard")
    }

    override public func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        refreshContent()
    }

    func refreshContent() {
        label.text = {
            switch content {
            case .default:
                return defaultErrorMessage
            case let .message(string):
                return string
            }
        }()
    }

    public func commonInit() {
        backgroundColor = .white
        separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 9_999)
        selectionStyle = .none
    }
}
