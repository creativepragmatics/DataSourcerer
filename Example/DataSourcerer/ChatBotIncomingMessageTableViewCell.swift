import Foundation
import UIKit

class ChatBotIncomingMessageTableViewCell : UITableViewCell {

    lazy var bubbleImageView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "chat_bubble_incoming")?.resizableImage(
            withCapInsets: UIEdgeInsets(top: 15, left: 25, bottom: 15, right: 15),
            resizingMode: .stretch
            )
        )

        self.contentView.addSubview(view)

        view.translatesAutoresizingMaskIntoConstraints = false
        view.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20).isActive = true
        view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        view.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 20).isActive = true
        view.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.4).isActive = true

        return view
    }()

    lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.numberOfLines = 0

        self.contentView.addSubview(label)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.topAnchor.constraint(equalTo: bubbleImageView.topAnchor, constant: 15).isActive = true
        label.bottomAnchor.constraint(equalTo: bubbleImageView.bottomAnchor, constant: -15).isActive = true
        label.leftAnchor.constraint(equalTo: bubbleImageView.leftAnchor, constant: 25).isActive = true
        label.rightAnchor.constraint(equalTo: bubbleImageView.rightAnchor, constant: -15).isActive = true

        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        _ = [bubbleImageView, messageLabel] // force init order
        self.backgroundColor = .clear
    }
}
