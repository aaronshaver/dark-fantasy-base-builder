import UIKit

final class AdminViewController: UITableViewController {
    var onNewGame: ((NewGameScenario) -> Void)?
    var onArtworkSaved: (([String: Data]) throws -> Void)?

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("Programmatic admin menu") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Admin"
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 2 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = indexPath.row == 0 ? "New Game Scenarios" : "Art Variation Generator"
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = indexPath.row == 0 ? "newGameScenarios" : "artVariationGenerator"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 0 {
            let scenarios = NewGameScenariosViewController()
            scenarios.onSelect = onNewGame
            navigationController?.pushViewController(scenarios, animated: true)
        } else {
            let artwork = ArtVariationGeneratorViewController()
            artwork.onArtworkSaved = onArtworkSaved
            navigationController?.pushViewController(artwork, animated: true)
        }
    }
}

final class NewGameScenariosViewController: UITableViewController {
    var onSelect: ((NewGameScenario) -> Void)?
    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("Programmatic scenarios menu") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "New Game Scenarios"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        NewGameScenario.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let scenario = NewGameScenario.allCases[indexPath.row]
        cell.textLabel?.text = scenario.title
        cell.accessibilityIdentifier = "newGameScenario_\(scenario.rawValue)"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let scenario = NewGameScenario.allCases[indexPath.row], start = onSelect
        dismiss(animated: true) { start?(scenario) }
    }
}
