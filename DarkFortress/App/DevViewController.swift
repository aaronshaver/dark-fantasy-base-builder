import UIKit

final class DevViewController: UITableViewController {
    var onNewGame: (() -> Void)?
    var onArtworkSaved: (([String: Data]) throws -> Void)?

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("Programmatic dev menu") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dev"
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 2 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = indexPath.row == 0 ? "New Game" : "Art Variations"
        cell.accessoryType = indexPath.row == 0 ? .none : .disclosureIndicator
        cell.accessibilityIdentifier = indexPath.row == 0 ? "newGame" : "artVariations"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 0 {
            let start = onNewGame
            dismiss(animated: true) { start?() }
        } else {
            let artwork = ArtVariationsViewController()
            artwork.onArtworkSaved = onArtworkSaved
            navigationController?.pushViewController(artwork, animated: true)
        }
    }
}
