import UIKit

final class DevViewController: UITableViewController {
    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("Programmatic dev menu") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dev"
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "Art Variations"
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "artVariations"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(ArtVariationsViewController(), animated: true)
    }
}

final class ArtVariationsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Art Variations"
        view.backgroundColor = .systemGroupedBackground
    }
}
