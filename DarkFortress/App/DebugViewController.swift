import UIKit

final class DebugViewController: UITableViewController {
    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("Programmatic debug menu") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Debug"
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
    private let repositoryDirectory = "/Users/aaronshaver/code/dark-fantasy-base-builder"
    private let result = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Art Variations"
        view.backgroundColor = .systemGroupedBackground

        let explanation = UILabel()
        explanation.text = "Save the current time into the repository. The text at the top of the game changes after your next build and run."
        explanation.numberOfLines = 0
        explanation.font = .preferredFont(forTextStyle: .body)
        explanation.adjustsFontForContentSizeCategory = true

        var configuration = UIButton.Configuration.filled()
        configuration.title = "Test Repository Write"
        let test = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            self?.testRepositoryWrite()
        })
        test.accessibilityIdentifier = "testRepositoryWrite"

        result.numberOfLines = 0
        result.font = .preferredFont(forTextStyle: .body)
        result.adjustsFontForContentSizeCategory = true
        result.accessibilityIdentifier = "repositoryWriteResult"

        let scroll = UIScrollView()
        let stack = UIStackView(arrangedSubviews: [explanation, test, result])
        stack.axis = .vertical
        stack.spacing = 24
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }

    private func testRepositoryWrite() {
        let file = URL(fileURLWithPath: repositoryDirectory, isDirectory: true)
            .appendingPathComponent("DarkFortress/Resources/WriteProbe/repository-write-test.txt")
        #if targetEnvironment(simulator)
        do {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "HH:mm:ss"
            let marker = "This text was written at \(formatter.string(from: Date()))"
            try Data(marker.utf8).write(to: file, options: .atomic)
            guard try String(contentsOf: file, encoding: .utf8) == marker else {
                throw NSError(domain: "RepositoryWriteTest", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "The saved file did not match when read back."])
            }
            result.text = "Saved and read back successfully. Build and run again to display this text at the top of the game.\n\nFile: \(file.path)\n\n\(marker)"
        } catch {
            let detail = error as NSError
            result.text = "Write failed. Maybe the repository directory is incorrect, or the app cannot access it.\n\nRepository directory: \(repositoryDirectory)\n\nFile: \(file.path)\n\nError: \(detail.localizedDescription)\n\(detail.domain) (\(detail.code))\n\(detail.userInfo)"
        }
        #else
        result.text = "This test requires the iOS Simulator on your Mac.\n\nRepository directory: \(repositoryDirectory)"
        #endif
    }
}
