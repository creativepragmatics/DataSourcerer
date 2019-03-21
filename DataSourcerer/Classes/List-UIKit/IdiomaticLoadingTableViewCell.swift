import Foundation
import UIKit

class IdiomaticLoadingTableViewCell : UITableViewCell {

    lazy var loadingIndicatorView: UIActivityIndicatorView = {
        let loadingIndicatorView = UIActivityIndicatorView(style: .gray)
        loadingIndicatorView.hidesWhenStopped = false
        self.contentView.addSubview(loadingIndicatorView)

        loadingIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicatorView.topAnchor.constraint(equalTo: self.contentView.topAnchor,
                                                  constant: 20).isActive = true
        loadingIndicatorView.centerXAnchor.constraint(equalTo: self.contentView.centerXAnchor).isActive = true
        loadingIndicatorView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor,
                                                     constant: -20).isActive = true

        return loadingIndicatorView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .white
        separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 9_999)
        selectionStyle = .none
        startAnimating()
    }

    func startAnimating() {
        loadingIndicatorView.startAnimating()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        startAnimating()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("IdiomaticLoadingTableViewCell cannot be used from a storyboard")
    }

}
