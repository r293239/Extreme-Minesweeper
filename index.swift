import SwiftUI
import Combine

// MARK: - Main App Entry Point
struct ContentView: View {
    var body: some View {
        MinesweeperGame()
            .preferredColorScheme(.light)
            .navigationBarHidden(true)
    }
}

// MARK: - Main Game View
struct MinesweeperGame: View {
    @StateObject private var game = MinesweeperViewModel()
    @StateObject private var settings = GameSettings()
    @State private var isFullScreen = false
    @State private var showSettings = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showGameOverAlert = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea(.all)
                
                VStack(spacing: isFullScreen ? 5 : 10) {
                    if !isFullScreen {
                        headerView
                    }
                    
                    gameGridView(geometry: geometry)
                    
                    if !isFullScreen {
                        controlsView
                    }
                }
                .padding(isFullScreen ? 2 : 10)
                
                // Game Over Overlay
                if game.gameStatus != .playing {
                    gameOverOverlay
                }
            }
        }
        .statusBarHidden(isFullScreen)
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings, game: game)
        }
        .alert("Game Over", isPresented: $showGameOverAlert) {
            Button("New Game") {
                resetGameState()
                game.resetGame()
            }
            Button("Continue", role: .cancel) { }
        } message: {
            Text(game.gameStatus == .won ? 
                 "Congratulations! You won in \(game.timeElapsed) seconds!" : 
                 "Game Over! Better luck next time.")
        }
        .onChange(of: game.gameStatus) { status in
            if status != .playing {
                showGameOverAlert = true
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            // Mine Count
            VStack {
                Text("💣")
                    .font(.title2)
                Text("\(game.mineCount)")
                    .font(.headline)
                    .foregroundColor(.red)
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Settings Button
            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            // Restart Button
            Button("Restart") {
                resetGameState()
                game.resetGame()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Spacer()
            
            // Timer
            VStack {
                Text("⏰")
                    .font(.title2)
                Text("\(game.timeElapsed)")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal)
    }
    
    private func gameGridView(geometry: GeometryProxy) -> some View {
        let baseCellSize: CGFloat = settings.cellSize
        let cellSize = baseCellSize * scale
        
        return ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(spacing: 1) {
                ForEach(0..<game.gridSize, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<game.gridSize, id: \.self) { col in
                            CellView(
                                cell: game.grid[row][col],
                                cellSize: cellSize,
                                isFlagMode: game.isFlagMode,
                                gameStatus: game.gameStatus,
                                settings: settings
                            ) {
                                handleCellTap(row: row, col: col)
                            }
                        }
                    }
                }
            }
            .padding(2)
            .background(Color.gray.opacity(0.3))
            .scaleEffect(scale)
            .offset(offset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .gesture(zoomAndPanGesture)
        .onTapGesture(count: 2) {
            resetZoomAndPan()
        }
    }
    
    private var zoomAndPanGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = min(max(lastScale * value, 0.3), 8.0)
                }
                .onEnded { _ in
                    lastScale = scale
                },
            
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    lastOffset = offset
                }
        )
    }
    
    private var controlsView: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isFullScreen.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        Text(isFullScreen ? "Exit Fullscreen" : "Fullscreen")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: {
                    game.toggleFlagMode()
                }) {
                    HStack {
                        Image(systemName: game.isFlagMode ? "flag.fill" : "flag")
                        Text(game.isFlagMode ? "Flag Mode ON" : "Flag Mode OFF")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(game.isFlagMode ? Color.red : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Zoom controls
                VStack {
                    Button("🔍+") {
                        adjustZoom(factor: 1.5)
                    }
                    .font(.caption)
                    
                    Button("🔍-") {
                        adjustZoom(factor: 0.67)
                    }
                    .font(.caption)
                }
            }
            
            statusBar
            
            Text("Pinch to zoom • Drag to pan • Double tap to reset • Long press for quick flag")
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
    
    private var statusBar: some View {
        HStack {
            Text(game.isFlagMode ? "Tap to Flag/Unflag" : "Tap to Reveal")
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
            Text("Zoom: \(String(format: "%.1f", scale))x")
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
            Text("Game: \(gameStatusText)")
                .font(.caption)
                .foregroundColor(gameStatusColor)
        }
    }
    
    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text(game.gameStatus == .won ? "🎉 Victory!" : "💀 Game Over")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                Text(game.gameStatus == .won ? 
                     "Time: \(game.timeElapsed)s" : 
                     "Better luck next time!")
                    .font(.title2)
                    .foregroundColor(.white)
                
                HStack(spacing: 20) {
                    Button("New Game") {
                        resetGameState()
                        game.resetGame()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Continue") {
                        showGameOverAlert = false
                    }
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
        }
    }
    
    // MARK: - Computed Properties
    private var gameStatusText: String {
        switch game.gameStatus {
        case .won: return "Won! 🎉"
        case .lost: return "Lost 💀"
        case .playing: return "Playing"
        }
    }
    
    private var gameStatusColor: Color {
        switch game.gameStatus {
        case .won: return .green
        case .lost: return .red
        case .playing: return .white
        }
    }
    
    // MARK: - Helper Methods
    private func handleCellTap(row: Int, col: Int) {
        if game.isFlagMode {
            game.toggleFlag(row: row, col: col)
        } else {
            game.revealCell(row: row, col: col)
        }
    }
    
    private func adjustZoom(factor: CGFloat) {
        scale = min(max(scale * factor, 0.3), 8.0)
        lastScale = scale
    }
    
    private func resetZoomAndPan() {
        withAnimation(.easeInOut(duration: 0.3)) {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
    
    private func resetGameState() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
        showGameOverAlert = false
    }
}

// MARK: - Cell View
struct CellView: View {
    let cell: Cell
    let cellSize: CGFloat
    let isFlagMode: Bool
    let gameStatus: GameStatus
    let settings: GameSettings
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Rectangle()
                    .fill(backgroundColor)
                    .frame(width: cellSize, height: cellSize)
                    .overlay(
                        Rectangle()
                            .stroke(borderColor, lineWidth: max(0.5, cellSize * 0.03))
                    )
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                
                cellContent
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.5) {
            // Quick flag on long press
            if gameStatus == .playing && !cell.isRevealed {
                // This would need to be handled by the parent view
            }
        }
        .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 50) { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        } perform: {
            onTap()
        }
    }
    
    @ViewBuilder
    private var cellContent: some View {
        if cell.isFlagged {
            Text("🚩")
                .font(.system(size: min(cellSize * 0.7, 35)))
        } else if cell.isRevealed {
            if cell.isMine {
                Text("💣")
                    .font(.system(size: min(cellSize * 0.7, 35)))
            } else if cell.adjacentMines > 0 {
                Text("\(cell.adjacentMines)")
                    .font(.system(size: min(cellSize * 0.6, 28), weight: .bold))
                    .foregroundColor(numberColor)
            }
        }
    }
    
    private var backgroundColor: Color {
        if cell.isRevealed {
            if cell.isMine {
                return gameStatus == .lost ? .red.opacity(0.8) : .red.opacity(0.7)
            } else {
                return .white
            }
        } else {
            return isFlagMode && !cell.isFlagged ? .blue.opacity(0.3) : .gray.opacity(0.8)
        }
    }
    
    private var borderColor: Color {
        if isFlagMode && !cell.isRevealed {
            return .blue.opacity(0.8)
        }
        return cell.isRevealed ? .gray.opacity(0.3) : .black.opacity(0.5)
    }
    
    private var numberColor: Color {
        switch cell.adjacentMines {
        case 1: return .blue
        case 2: return .green
        case 3: return .red
        case 4: return .purple
        case 5: return .brown
        case 6: return .pink
        case 7: return .black
        case 8: return .gray
        default: return .black
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var settings: GameSettings
    @ObservedObject var game: MinesweeperViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Difficulty") {
                    Picker("Difficulty", selection: $settings.difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { difficulty in
                            Text(difficulty.rawValue).tag(difficulty)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Grid Settings") {
                    HStack {
                        Text("Grid Size: \(settings.gridSize)")
                        Spacer()
                        Stepper("", value: $settings.gridSize, in: 10...60, step: 2)
                    }
                    
                    HStack {
                        Text("Mine Count: \(settings.mineCount)")
                        Spacer()
                        Stepper("", value: $settings.mineCount, in: 10...min(500, settings.gridSize * settings.gridSize / 4))
                    }
                    
                    HStack {
                        Text("Cell Size: \(Int(settings.cellSize))")
                        Spacer()
                        Slider(value: $settings.cellSize, in: 15...40, step: 1)
                    }
                }
                
                Section("Statistics") {
                    HStack {
                        Text("Games Played")
                        Spacer()
                        Text("\(settings.gamesPlayed)")
                    }
                    
                    HStack {
                        Text("Games Won")
                        Spacer()
                        Text("\(settings.gamesWon)")
                    }
                    
                    HStack {
                        Text("Win Rate")
                        Spacer()
                        Text(settings.winRate)
                    }
                    
                    HStack {
                        Text("Best Time")
                        Spacer()
                        Text(settings.bestTime > 0 ? "\(settings.bestTime)s" : "N/A")
                    }
                }
                
                Section {
                    Button("Reset Statistics") {
                        settings.resetStats()
                    }
                    .foregroundColor(.red)
                    
                    Button("Apply Settings") {
                        game.applySettings(settings)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Game Settings
class GameSettings: ObservableObject {
    @Published var difficulty: Difficulty = .expert {
        didSet {
            applyDifficulty()
        }
    }
    @Published var gridSize: Int = 48
    @Published var mineCount: Int = 480
    @Published var cellSize: CGFloat = 25
    
    // Statistics
    @Published var gamesPlayed: Int = 0
    @Published var gamesWon: Int = 0
    @Published var bestTime: Int = 0
    
    var winRate: String {
        guard gamesPlayed > 0 else { return "0%" }
        let rate = Double(gamesWon) / Double(gamesPlayed) * 100
        return String(format: "%.1f%%", rate)
    }
    
    init() {
        applyDifficulty()
    }
    
    private func applyDifficulty() {
        switch difficulty {
        case .beginner:
            gridSize = 16
            mineCount = 40
        case .intermediate:
            gridSize = 32
            mineCount = 200
        case .expert:
            gridSize = 48
            mineCount = 480
        case .custom:
            // Keep current values
            break
        }
    }
    
    func recordGame(won: Bool, time: Int) {
        gamesPlayed += 1
        if won {
            gamesWon += 1
            if bestTime == 0 || time < bestTime {
                bestTime = time
            }
        }
    }
    
    func resetStats() {
        gamesPlayed = 0
        gamesWon = 0
        bestTime = 0
    }
}

enum Difficulty: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case expert = "Expert"
    case custom = "Custom"
}

// MARK: - Game View Model
class MinesweeperViewModel: ObservableObject {
    @Published var grid: [[Cell]] = []
    @Published var gameStatus: GameStatus = .playing
    @Published var mineCount: Int = 480
    @Published var timeElapsed: Int = 0
    @Published var isFlagMode: Bool = false
    
    var gridSize = 48
    private var totalMines = 480
    private var timer: Timer?
    private var gameStarted = false
    
    init() {
        resetGame()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func applySettings(_ settings: GameSettings) {
        gridSize = settings.gridSize
        totalMines = settings.mineCount
        mineCount = totalMines
        resetGame()
    }
    
    func resetGame() {
        gameStatus = .playing
        mineCount = totalMines
        timeElapsed = 0
        gameStarted = false
        isFlagMode = false
        timer?.invalidate()
        initializeGrid()
        revealCenterPieces()
    }
    
    func toggleFlagMode() {
        isFlagMode.toggle()
    }
    
    private func initializeGrid() {
        grid = Array(repeating: Array(repeating: Cell(), count: gridSize), count: gridSize)
    }
    
    private func revealCenterPieces() {
        let center = gridSize / 2
        let positions = [
            (center - 1, center - 1),
            (center - 1, center),
            (center, center - 1),
            (center, center)
        ]
        
        placeMinesAvoidingCenter()
        
        for (row, col) in positions {
            grid[row][col].isRevealed = true
            if grid[row][col].adjacentMines == 0 {
                revealAdjacentCells(row: row, col: col)
            }
        }
        
        gameStarted = true
        startTimer()
    }
    
    private func placeMinesAvoidingCenter() {
        let center = gridSize / 2
        let avoidPositions = Set([
            "\(center-1),\(center-1)",
            "\(center-1),\(center)",
            "\(center),\(center-1)",
            "\(center),\(center)"
        ])
        
        var minesPlaced = 0
        var attempts = 0
        let maxAttempts = totalMines * 10
        
        while minesPlaced < totalMines && attempts < maxAttempts {
            let row = Int.random(in: 0..<gridSize)
            let col = Int.random(in: 0..<gridSize)
            attempts += 1
            
            if avoidPositions.contains("\(row),\(col)") || grid[row][col].isMine {
                continue
            }
            
            grid[row][col].isMine = true
            minesPlaced += 1
        }
        
        // Calculate adjacent mine counts
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if !grid[row][col].isMine {
                    grid[row][col].adjacentMines = countAdjacentMines(row: row, col: col)
                }
            }
        }
    }
    
    private func countAdjacentMines(row: Int, col: Int) -> Int {
        var count = 0
        for r in max(0, row-1)...min(gridSize-1, row+1) {
            for c in max(0, col-1)...min(gridSize-1, col+1) {
                if r != row || c != col, grid[r][c].isMine {
                    count += 1
                }
            }
        }
        return count
    }
    
    func revealCell(row: Int, col: Int) {
        guard gameStatus == .playing,
              !grid[row][col].isRevealed,
              !grid[row][col].isFlagged else { return }
        
        grid[row][col].isRevealed = true
        
        if grid[row][col].isMine {
            gameStatus = .lost
            timer?.invalidate()
            revealAllMines()
        } else {
            if grid[row][col].adjacentMines == 0 {
                revealAdjacentCells(row: row, col: col)
            }
            checkWinCondition()
        }
    }
    
    private func revealAdjacentCells(row: Int, col: Int) {
        for r in max(0, row-1)...min(gridSize-1, row+1) {
            for c in max(0, col-1)...min(gridSize-1, col+1) {
                if r != row || c != col,
                   !grid[r][c].isRevealed,
                   !grid[r][c].isFlagged {
                    revealCell(row: r, col: c)
                }
            }
        }
    }
    
    private func revealAllMines() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if grid[row][col].isMine {
                    grid[row][col].isRevealed = true
                }
            }
        }
    }
    
    func toggleFlag(row: Int, col: Int) {
        guard gameStatus == .playing,
              !grid[row][col].isRevealed else { return }
        
        grid[row][col].isFlagged.toggle()
        mineCount += grid[row][col].isFlagged ? -1 : 1
    }
    
    private func checkWinCondition() {
        let revealedCells = grid.flatMap { $0 }.filter { $0.isRevealed && !$0.isMine }.count
        let totalSafeCells = gridSize * gridSize - totalMines
        
        if revealedCells == totalSafeCells {
            gameStatus = .won
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.timeElapsed += 1
        }
    }
}

// MARK: - Data Models
struct Cell {
    var isMine = false
    var isRevealed = false
    var isFlagged = false
    var adjacentMines = 0
}

enum GameStatus {
    case playing
    case won
    case lost
}

// MARK: - Preview
#Preview {
    ContentView()
}
