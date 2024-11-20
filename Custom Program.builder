require 'gosu'
require 'json'

# Class to hold the game settings
class GameSettings
  attr_accessor :screen_width, :screen_height, :game_width, :game_height, :block_rows, :block_columns, :ball_speed, :platform_speed

  # Initialize the game setting with the given parameters
  def initialize(screen_width, screen_height, game_width, game_height, block_rows, block_columns, ball_speed, platform_speed)
    @screen_width = screen_width
    @screen_height = screen_height
    @game_width = game_width
    @game_height = game_height
    @block_rows = block_rows
    @block_columns = block_columns
    @ball_speed = ball_speed
    @platform_speed = platform_speed
  end
end

# Class that represents a block within the game
class Block
  attr_accessor :x, :y, :width, :height, :is_destroyed

  # Initialize a block with position and size
  def initialize(x, y, width, height)
    @x = x
    @y = y
    @width = width
    @height = height
    @is_destroyed = false # Indicates block state is not destroyed at first
  end
end

# Class representing the ball in the game
class Ball
  attr_accessor :x, :y, :radius, :dx, :dy, :color

  # Initialize ball with position, speed, and color
  def initialize(x, y, radius, dx, dy, color)
    @x = x
    @y = y
    @radius = radius
    @dx = dx
    @dy = dy
    @color = color
  end
end

# Class representing the platform controlled by the player
class Platform
  attr_accessor :x, :y, :width, :height

  # Initialize the platform with the position and size
  def initialize(x, y, width, height)
    @x = x
    @y = y
    @width = width
    @height = height
  end
end

# Class to hold the game state
# Game State variables are encapsulated within the GameState class which avoids the use of global variables
class GameState
  attr_accessor :blocks, :balls, :platform, :score, :initial_score, :lives, :is_game_over, :paused, :show_leaderboard

  # Initialize the game state with default values
  def initialize
    @blocks = []
    @balls = []
    @platform = nil
    @score = 0
    @initial_score = 0
    @lives = 3
    @is_game_over = false # Flag for indicating if game is lost by player
    @paused = false # Flag for indicating if the game is initially paused
    @show_leaderboard = false # Flag for shoowing leaderboard
  end
end


# Class to manage the scoreboard
# Scoreboard class encapsulates the score data and prevents any global scope pollution (defining too many variables / functions in the global scope)
class Scoreboard
  FILE_NAME = "score.json"

  # Initialize scoreboard and load the scores from the file
  def initialize
    @scores = load_scores
  end

  # load scores from JSON file
  def load_scores
    if File.exist?(FILE_NAME)
      JSON.parse(File.read(FILE_NAME))
    else
      []
    end
  end

  # Save scores to JSON file
  def save_scores
    File.write(FILE_NAME, @scores.to_json) # Scores are saved into the JSON file
  end

  # Add a new score and update the scoreboard
  def add_score(score, lives)

    # Adds a new score entry to the scores list
    @scores << { 'score' => score, 'lives' => lives }

    # Ensures that only valid score entries are retained
    # @scores array in the scoreboard class stores hashes with keys which represents each player's score entry
    @scores = @scores.select { |entry| entry.is_a?(Hash) && entry.key?('score') }

    # Sort the scores in descending order
    @scores.sort_by! { |entry| -entry['score'] }

    # Keep only the top 10 scores
    @scores = @scores.take(10)

    # Save the updated scores to the file
    save_scores
  end

  # Return the top scores
  def top_scores
    @scores
  end
end

# Main game class using Gosu
class BlockBreakerGame < Gosu::Window
  def initialize
    screen_width = 1000
    screen_height = 600
    game_width = 800
    game_height = 600
    @game_settings = GameSettings.new(screen_width, screen_height, game_width, game_height, 5, 10, 4.0, 6.0)
    @game_state = GameState.new
    @scoreboard = Scoreboard.new
    initialize_game(@game_state, @game_settings)

    super(@game_settings.screen_width, @game_settings.screen_height)
    self.caption = "Block Breaker"
    @font = Gosu::Font.new(20)
    @last_esc_press = 0  # Used to keep track of last ESC key press
    @last_l_press = 0 # Used to keep track of last L key press
    @key_cooldown = 200  # Cooldown period in milliseconds
  end

  # Initialize the game state with blocks, platform and balls
  # Functional decomposition
  def initialize_game(game_state, game_settings)
    game_state.platform = Platform.new(game_settings.game_width / 2, game_settings.game_height - 30, 100, 20)
    game_state.balls << Ball.new(game_settings.game_width / 2, game_settings.game_height / 2, 10, game_settings.ball_speed, game_settings.ball_speed, Gosu::Color::RED)

    block_width = game_settings.game_width / game_settings.block_columns
    block_height = 30

    # Loops used to create blocks and update game objects
    game_settings.block_rows.times do |row|
      game_settings.block_columns.times do |col|
        x = col * block_width
        y = row * block_height
        game_state.blocks << Block.new(x, y, block_width, block_height)
      end
    end

    game_state.initial_score = game_state.score
  end

  # Update the game state
  # Functional decomposition by delegating tasks to other methods (i.e handle_menu_input and update_game_state) depending on game state
  def update
    if @game_state.is_game_over || @game_state.paused
      handle_menu_input
    else
      handle_input
      update_game_state(@game_state, @game_settings)
    end
  end

  # Draw the game elements
  # Functional decomposition - responsible for drawing the appropriate screens based on game state by breaking tasks into smaller functions (i.e draw_pause_screen)
  def draw
    if @game_state.show_leaderboard
      draw_leaderboard
    elsif @game_state.is_game_over
      if @game_state.blocks.empty?
        draw_you_win_screen
      else
        draw_game_over_screen
      end
    elsif @game_state.paused
      draw_pause_screen
    else
      render_game(@game_state)
    end
  end

  # Handle the input during the game
  # uses conditional statements like if and elsif to determine actions based on player input
  def handle_input
    if Gosu.button_down? Gosu::KB_LEFT
      @game_state.platform.x -= @game_settings.platform_speed if @game_state.platform.x > 0
    end
    if Gosu.button_down? Gosu::KB_RIGHT
      @game_state.platform.x += @game_settings.platform_speed if @game_state.platform.x < @game_settings.game_width - @game_state.platform.width
    end
    if Gosu.button_down? Gosu::KB_ESCAPE
      current_time = Gosu.milliseconds
      if current_time - @last_esc_press > @key_cooldown
        toggle_pause
        @last_esc_press = current_time
      end
    end
    if Gosu.button_down? Gosu::KB_L
      current_time = Gosu.milliseconds
      if current_time - @last_l_press > @key_cooldown
        @game_state.show_leaderboard = !@game_state.show_leaderboard
        @last_l_press = current_time
      end
    end
  end

  # Handle input when in menu
  def handle_menu_input
    if Gosu.button_down? Gosu::KB_R
      reset_game
    elsif Gosu.button_down? Gosu::KB_ESCAPE
      current_time = Gosu.milliseconds
      if current_time - @last_esc_press > @key_cooldown
        toggle_pause if @game_state.paused
        @last_esc_press = current_time
      end

    elsif Gosu.button_down? Gosu::KB_L
      current_time = Gosu.milliseconds
      if current_time - @last_l_press > @key_cooldown
        @game_state.show_leaderboard = !@game_state.show_leaderboard
        @last_l_press = current_time
      end
    end
  end


  # Toggle the pause game state (associated with paused game esc key)
  def toggle_pause
    @game_state.paused = !@game_state.paused
  end

  # Update the game state logic
  # Follows a sequence of steps to update the game state
  def update_game_state(game_state, game_settings)
    game_state.balls.each do |ball|

      # Update the ball position
      ball.x += ball.dx
      ball.y += ball.dy

      # Handle ball collision with side wall
      if ball.x - ball.radius < 0 || ball.x + ball.radius > game_settings.game_width

        # Reverse horizontal direction
        ball.dx = -ball.dx
        ball.color = Gosu::Color::BLUE  # Change color upon wall collision
      end

      # Handle ball collision with top wall
      if ball.y - ball.radius < 0

        # Reverse the vertical direction
        ball.dy = -ball.dy
        ball.color = Gosu::Color::GREEN  # Change color upon wall collision
      end

      # Handle ball collision with platform
      if ball.y + ball.radius > game_state.platform.y && ball.x > game_state.platform.x && ball.x < game_state.platform.x + game_state.platform.width

        # Reverse the vertical direction
        ball.dy = -ball.dy
      end

      # Handle ball collision with blocks
      # array is used to manage multiple game objects and repeating over these arrays allows for updating and rendering of each object
      game_state.blocks.each do |block|
        if !block.is_destroyed && ball.y - ball.radius < block.y + block.height && ball.y + ball.radius > block.y && ball.x > block.x && ball.x < block.x + block.width

          # Mark block as destroyed
          block.is_destroyed = true

          # Reverse vertical direction
          ball.dy = -ball.dy
          ball.color = Gosu::Color::YELLOW  # Change color upon block collision

          # Increase the score
          game_state.score += 10
        end
      end

      # Handle ball going below bottom of the screen
      if ball.y > game_settings.game_height

        # Decrease lives
        game_state.lives -= 1

        if game_state.lives > 0

          # Deduct a percentage of the score based on remaining lives
          # Case statement is used to handle different actions based on number of lives remaining
          case game_state.lives
          when 2
            deduction_percentage = 0.10
          when 1
            deduction_percentage = 0.25
          end

        deduction_amount = (game_state.score * deduction_percentage).to_i
        game_state.score -= deduction_amount # Deduct score
        game_state.score = [game_state.score, game_state.initial_score].max  # Ensure score does not go below initial score
        reset_ball(ball, game_state) # Reset the ball position
        else
          game_state.is_game_over = true # Set game over state
          @scoreboard.add_score(game_state.score, game_state.lives) # Add score to scoreboard
        end
      end
    end

    # Remove destroyed blocks from game state
    game_state.blocks.reject! { |block| block.is_destroyed }

    # Check for game completion
    if game_state.blocks.empty?
      game_state.is_game_over = true # Set game over state
      @scoreboard.add_score(game_state.score, game_state.lives) # Add score to the scoreboard
    end
  end

  # Reset the ball if the ball falls off screen (ball fall off screen, respawn)
  def reset_ball(ball, game_state)

    # Position the ball at the center of the platform
    ball.x = game_state.platform.x + game_state.platform.width / 2

    # Position ball above the platform
    ball.y = game_state.platform.y - 280

    # Reset the horizontal speed of the ball
    ball.dx = @game_settings.ball_speed

    # Reset the vertical speed of the ball
    ball.dy = @game_settings.ball_speed
  end

  # Reset the game state
  def reset_game
    @game_state = GameState.new
    initialize_game(@game_state, @game_settings)
  end

  # Render the game elements (used to generate blocks, scores, and elements in the game)
  def render_game(game_state)
    draw_rect(200, 0, @game_settings.game_width, @game_settings.game_height, Gosu::Color::BLACK)

    game_state.blocks.each do |block|
      unless block.is_destroyed
        draw_rect(200 + block.x - 1, block.y - 1, block.width + 2, block.height + 2, Gosu::Color::BLACK)
        draw_rect(200 + block.x, block.y, block.width, block.height, Gosu::Color::RED)
      end
    end

    # array used to store object, repeating over these array allows for updating and rendering of each object
    game_state.balls.each do |ball|
      draw_circle(200 + ball.x, ball.y, ball.radius, ball.color)
    end

    draw_rect(200 + game_state.platform.x, game_state.platform.y, game_state.platform.width, game_state.platform.height, Gosu::Color::GREEN)

    draw_rect(0, 0, 200, @game_settings.game_height, Gosu::Color::GRAY)
    @font.draw_text("Score:", 70, 10, 1, 1.0, 1.0, Gosu::Color::CYAN)
    @font.draw_text(@game_state.score.to_s, 90, 50, 1, 1.0, 1.0, Gosu::Color::YELLOW)

    @font.draw_text("Lives left:", 60, 100, 1, 1.0, 1.0, Gosu::Color::CYAN)
    @font.draw_text(@game_state.lives.to_s, 90, 140, 1, 1.0, 1.0, Gosu::Color::YELLOW)
  end

  # draw the ball with the given parameters (ball creation)
  # circle is drawn through 32 triangles
  def draw_circle(x, y, radius, color)
    32.times do |i|

      # Calculate the angle for the current and next triangle vertices
      angle1 = (i / 32.0) * 2 * Math::PI
      angle2 = ((i + 1) / 32.0) * 2 * Math::PI

      # Draw triangle between center of the circle and two calculated vertices
      draw_triangle(x, y, color, x + Math.cos(angle1) * radius, y + Math.sin(angle1) * radius, color, x + Math.cos(angle2) * radius, y + Math.sin(angle2) * radius, color)
    end
  end

  # Draw the pause screen (esc key pause screen)
  def draw_pause_screen
    draw_rect(0, 0, @game_settings.screen_width, @game_settings.screen_height, Gosu::Color::rgba(0, 0, 0, 150))
    @font.draw_text("Paused", 400, 200, 2, 2.0, 2.0, Gosu::Color::WHITE)
    @font.draw_text("Press 'R' to Retry", 350, 300, 2, 1.5, 1.5, Gosu::Color::WHITE)
    @font.draw_text("Press 'L' to View Leaderboard", 350, 350, 2, 1.5, 1.5, Gosu::Color::WHITE)
    @font.draw_text("Press 'ESC' to Resume", 350, 400, 2, 1.5, 1.5, Gosu::Color::WHITE)
  end

  # Draw the game over screen (lose all lives screen)
  def draw_game_over_screen
    draw_rect(0, 0, @game_settings.screen_width, @game_settings.screen_height, Gosu::Color::rgba(0, 0, 0, 150))
    @font.draw_text("Game Over", 350, 200, 2, 2.0, 2.0, Gosu::Color::RED)
    @font.draw_text("Score: #{@game_state.score}", 350, 300, 2, 1.5, 1.5, Gosu::Color::GREEN)
    @font.draw_text("Lives left: #{@game_state.lives}", 350, 350, 2, 1.5, 1.5, Gosu::Color::GREEN)
    @font.draw_text("Press 'R' to Retry", 350, 400, 2, 1.5, 1.5, Gosu::Color::WHITE)
    @font.draw_text("Press 'L' to View Leaderboard", 350, 450, 2, 1.5, 1.5, Gosu::Color::WHITE)
  end

  # Draw the winning screen (destroy all blocks screen)
  def draw_you_win_screen
    draw_rect(0, 0, @game_settings.screen_width, @game_settings.screen_height, Gosu::Color::rgba(0, 0, 0, 150))
    @font.draw_text("You win! Thanks for playing!", 250, 200, 2, 2.0, 2.0, Gosu::Color::GREEN)
    @font.draw_text("Score: #{@game_state.score}", 350, 300, 2, 1.5, 1.5, Gosu::Color::GREEN)
    @font.draw_text("Lives left: #{@game_state.lives}", 350, 350, 2, 1.5, 1.5, Gosu::Color::GREEN)
    @font.draw_text("Press 'R' to Retry", 350, 400, 2, 1.5, 1.5, Gosu::Color::WHITE)
    @font.draw_text("Press 'L' to View Leaderboard", 350, 450, 2, 1.5, 1.5, Gosu::Color::WHITE)
  end

  # Draw the leaderboard (l key leaderboard screen)
  def draw_leaderboard
    draw_rect(0, 0, @game_settings.screen_width, @game_settings.screen_height, Gosu::Color::rgba(0, 0, 0, 150))

    # Calculate the x position to center the leaderboard title
    leaderboard_title_x = (@game_settings.screen_width - @font.text_width("Leaderboard", 2.0)) / 2

    # Set the y position for the leaderboard title
    leaderboard_title_y = 50

    # Draw the leaderboard title centered
    @font.draw_text("Leaderboard", leaderboard_title_x, leaderboard_title_y, 2, 2.0, 2.0, Gosu::Color::WHITE)

    # Repeat through each score entry and display it
    top_scores = @scoreboard.top_scores
    top_scores.each_with_index do |entry, index|
      score = entry['score']
      lives = entry['lives']

      # Format the score text
      score_text = "#{index + 1}. Score: #{score} - Lives Remaining: #{lives}"

      # Calculate the x position to center the score text
      score_x = (@game_settings.screen_width - @font.text_width(score_text, 1.0)) / 2

      # Set the Y-Position for each score entry, with a gap of 30 pixels between entries
      score_y = 100 + index * 30

      # Draw the score text centered on the screen
      @font.draw_text(score_text, score_x, score_y, 1, 1.0, 1.0, Gosu::Color::WHITE)
    end
  end
end

# Start the game
BlockBreakerGame.new.show
