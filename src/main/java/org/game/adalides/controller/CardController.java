package org.game.adalides.controller;

import org.game.adalides.exception.CardNotFoundException;
import org.game.adalides.domain.CardElement;
import org.game.adalides.repository.CardRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;

import javax.validation.Valid;
import java.util.List;

@RestController
public class CardController {

    @Autowired
    CardRepository cardRepository;

    // Get All Notes
    @GetMapping("/cards")
    public List<CardElement> getAllNotes() {
        return cardRepository.findAll();
    }

    // Create a new Note
    @PostMapping("/cards")
    public CardElement createNote(@Valid @RequestBody CardElement card) {
        return cardRepository.save(card);
    }

    // Get a Single card
    @GetMapping("/card/{id}")
    public CardElement getNoteById(@PathVariable(value = "id") Long cardId) throws CardNotFoundException {
        return cardRepository.findById(cardId)
                .orElseThrow(() -> new CardNotFoundException(cardId));
    }

    // Update a Note
    @PutMapping("/cards/{id}")
    public CardElement updateNote(@PathVariable(value = "id") Long cardId,
                           @Valid @RequestBody CardElement usersDetails) throws CardNotFoundException {

        CardElement card = cardRepository.findById(cardId)
                .orElseThrow(() -> new CardNotFoundException(cardId));

        card.setName(usersDetails.getName());
        card.setAttack(usersDetails.getAttack());
        card.setDefense(usersDetails.getDefense());
        //cart
        // card.setAuthor_name(bookDetails.getAuthor_name());
        // card.setIsbn(bookDetails.getIsbn());

        CardElement updateCard = cardRepository.save(card);

        return updateCard;
    }

    // Delete a Note
    @DeleteMapping("/cards/{id}")
    public ResponseEntity<?> deleteBook(@PathVariable(value = "id") Long cardId) throws CardNotFoundException {
        CardElement card = cardRepository.findById(cardId)
                .orElseThrow(() -> new CardNotFoundException(cardId));

        cardRepository.delete(card);

        return ResponseEntity.ok().build();
    }
}
