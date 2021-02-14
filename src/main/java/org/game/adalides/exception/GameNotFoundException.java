package org.game.adalides.exception;

public class GameNotFoundException extends Exception {
    private long game_id;
    public GameNotFoundException(long game_id) {
        super(String.format("Game is not found with id : '%s'", game_id));
    }

}
