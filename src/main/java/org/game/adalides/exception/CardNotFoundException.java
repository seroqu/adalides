package org.game.adalides.exception;

public class CardNotFoundException extends Exception {
    private long card_id;
    public CardNotFoundException(long card_id) {
        super(String.format("Card is not found with id : '%s'", card_id));
    }
}

