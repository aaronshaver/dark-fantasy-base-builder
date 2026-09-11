import UIKit
#if DEBUG && targetEnvironment(simulator)
import FortressArt
import PixelArt

final class ArtVariationsViewController: UIViewController {
    var onArtworkSaved: (([String: Data]) throws -> Void)?
    private let picker = UIButton(type: .system)
    private let intensity = UISlider()
    private let intensityLabel = UILabel()
    private let generate = UIButton(type: .system)
    private let save = UIButton(type: .system)
    private let status = UILabel()
    private let currentTitle = UILabel()
    private let candidateTitle = UILabel()
    private let currentGrid = ArtworkGridView()
    private let candidateGrid = ArtworkGridView()
    private let queue = DispatchQueue(label: "DarkFortress.artwork", qos: .userInitiated)
    private var session: ArtworkSession?
    private var selection = ArtCatalog.definitions[0].id
    private var busy = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Art Variations"
        view.backgroundColor = .systemGroupedBackground
        configureLayout()
        load(selection)
    }

    private func configureLayout() {
        picker.configuration = .tinted()
        picker.configuration?.image = UIImage(systemName: "chevron.down")
        picker.configuration?.imagePlacement = .trailing
        picker.configuration?.imagePadding = 12
        picker.showsMenuAsPrimaryAction = true
        picker.accessibilityIdentifier = "artworkPicker"
        intensity.minimumValue = 0
        intensity.maximumValue = 1
        intensity.value = 0.25
        intensity.accessibilityLabel = "Variation intensity"
        intensity.accessibilityIdentifier = "variationIntensity"
        intensity.addTarget(self, action: #selector(intensityChanged), for: .valueChanged)
        intensityLabel.font = .preferredFont(forTextStyle: .subheadline)
        intensityChanged()
        for label in [currentTitle, candidateTitle] { label.font = .preferredFont(forTextStyle: .headline); label.numberOfLines = 0 }
        currentTitle.text = "Current artwork"
        candidateTitle.text = "Candidate"
        configureButton(generate, title: "Generate Variation", id: "generateVariation", action: #selector(generateVariation))
        configureButton(save, title: "Save Variation", id: "saveVariation", action: #selector(saveVariation))
        save.configuration = .borderedProminent()
        save.configuration?.title = "Save Variation"
        save.titleLabel?.numberOfLines = 2
        let buttons = UIStackView(arrangedSubviews: [generate, save])
        buttons.spacing = 12; buttons.distribution = .fillEqually
        status.font = .preferredFont(forTextStyle: .footnote)
        status.textColor = .secondaryLabel; status.numberOfLines = 0
        status.accessibilityIdentifier = "artworkGenerationStatus"
        let subtle = UILabel(), dramatic = UILabel()
        subtle.text = "Subtle"; dramatic.text = "Dramatic"
        for label in [subtle, dramatic] { label.font = .preferredFont(forTextStyle: .caption1); label.textColor = .secondaryLabel }
        let endpoints = UIStackView(arrangedSubviews: [subtle, UIView(), dramatic])
        let divider = UIView(); divider.backgroundColor = .separator
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let content = UIStackView(arrangedSubviews: [picker, currentTitle, currentGrid, divider,
            intensityLabel, intensity, endpoints, buttons, status, candidateTitle, candidateGrid])
        content.axis = .vertical; content.spacing = 16
        content.setCustomSpacing(0, after: intensity)
        content.setCustomSpacing(8, after: currentTitle)
        content.setCustomSpacing(8, after: candidateTitle)
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll); scroll.addSubview(content)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    private func configureButton(_ button: UIButton, title: String, id: String, action: Selector) {
        button.configuration = .bordered()
        button.configuration?.title = title
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.accessibilityIdentifier = id
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func updateControls() {
        picker.isEnabled = !busy
        intensity.isEnabled = !busy
        generate.isEnabled = !busy && session != nil
        save.isEnabled = !busy && session?.candidate != nil
        navigationItem.hidesBackButton = busy
        navigationController?.isModalInPresentation = busy
        let name = ArtCatalog.definitions.first { $0.id == selection }?.name
        picker.configuration?.title = name
        picker.menu = UIMenu(children: ArtCatalog.definitions.map { definition in
            UIAction(title: definition.name, state: definition.id == selection ? .on : .off) { [weak self] _ in
                self?.load(definition.id)
            }
        })
    }

    private func load(_ id: String) {
        selection = id; session = nil; busy = true
        currentGrid.show([]); candidateGrid.show([])
        currentTitle.text = "Current artwork"; candidateTitle.text = "Candidate"
        status.text = "Loading artwork…"
        updateControls()
        queue.async { [weak self] in
            let result = Result { try ArtworkRepository.store.load(id: id) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                do {
                    let artwork = try result.get()
                    self.currentGrid.show(try self.previews(artwork))
                    self.session = ArtworkSession(accepted: artwork)
                    self.currentTitle.text = "Current artwork · \(artwork.frames.count) frames"
                    self.status.text = "Generate a variation to compare. Changes are accepted only when you save."
                } catch { self.show(error) }
                self.updateControls()
            }
        }
    }

    @objc private func intensityChanged() {
        let percentage = Int((intensity.value * 100).rounded())
        intensityLabel.text = "Variation Intensity · \(percentage)%"
        intensity.accessibilityValue = "\(percentage) percent"
    }

    @objc private func generateVariation() {
        guard let original = session, !busy else { return }
        busy = true; status.text = "Generating the complete frame set…"; updateControls()
        let amount = Double(intensity.value)
        let seed = UInt64.random(in: UInt64.min...UInt64.max)
        queue.async { [weak self] in
            let result = Result { () -> ArtworkSession in
                var next = original
                try next.generate(intensity: amount, seed: seed)
                return next
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                do {
                    let next = try result.get()
                    if let candidate = next.candidate {
                        self.candidateGrid.show(try self.previews(candidate))
                        self.session = next
                        self.candidateTitle.text = "Candidate · \(candidate.frames.count) frames · \(Int((amount * 100).rounded()))%"
                        self.status.text = "Candidate ready. Save accepts the entire set."
                    }
                } catch { self.status.text = String(describing: error) }
                self.updateControls()
            }
        }
    }

    @objc private func saveVariation() {
        guard let original = session, let candidate = original.candidate, !busy else { return }
        busy = true; status.text = "Saving the complete frame set…"; updateControls()
        let apply = onArtworkSaved
        queue.async { [weak self] in
            let result = Result { try ArtworkRepository.store.save(candidate, replacing: original.accepted) }
            DispatchQueue.main.async {
                var refreshError: Error?
                if case .success = result {
                    do { try apply?(candidate.pngs) } catch { refreshError = error }
                }
                guard let self else { return }
                self.busy = false
                do {
                    try result.get()
                    var accepted = original; accepted.acceptSavedCandidate()
                    self.session = accepted
                    self.currentGrid.show(try self.previews(accepted.accepted))
                    self.currentTitle.text = "Current artwork · \(candidate.frames.count) frames"
                    self.candidateGrid.show([]); self.candidateTitle.text = "Candidate"
                    self.status.text = "Saved \(candidate.frames.count) frames. New variations will start from this artwork."
                    if let refreshError { self.status.text = "Saved, but could not refresh the game: \(refreshError)" }
                } catch { self.show(error) }
                self.updateControls()
            }
        }
    }

    private func previews(_ artwork: RenderedArtwork) throws -> [(name: String, image: UIImage)] {
        try artwork.frames.map { frame in
            guard let image = UIImage(data: frame.png) else { throw ArtError.invalid("Cannot read image: \(frame.name)") }
            let prefix = artwork.state.id + "_"
            let caption = frame.name.hasPrefix(prefix) ? String(frame.name.dropFirst(prefix.count)) : frame.name
            return (caption, image)
        }
    }

    private func show(_ error: Error) {
        status.text = "\(error)\nProject directory: \(ArtworkRepository.root.path)"
    }
}
#else
final class ArtVariationsViewController: UIViewController {
    var onArtworkSaved: (([String: Data]) throws -> Void)?
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Art Variations"
        view.backgroundColor = .systemGroupedBackground
        let label = UILabel()
        label.text = "Artwork authoring is available in simulator development builds."
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            label.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20)
        ])
    }
}
#endif
