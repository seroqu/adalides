package org.game.adalides.controller;

import org.game.adalides.domain.Game;
import org.game.adalides.exception.GameNotFoundException;
import org.game.adalides.repository.GameRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import java.util.List;


@RestController
public class GameController {

    @Autowired
    GameRepository gameRepository;

    // Get All Notes
    @GetMapping("/games")
    public List<Game> getAllGames() {
        return gameRepository.findAll();
    }

    // Create a new Game
    @PostMapping("/games")
    public Game createGame(@Valid @RequestBody Game game) {
        return gameRepository.save(game);
    }

    // Get a normal Game
    @GetMapping("/games/{id}")
    public Game getGameById(@PathVariable(value = "id") Long gameId) throws GameNotFoundException {
        return gameRepository.findById(gameId)
                .orElseThrow(() -> new GameNotFoundException(gameId));
    }

    // Update a Note
    @PutMapping("/games/{id}")
    public Game updateGame(@PathVariable(value = "id") Long gameId,
                           @Valid @RequestBody Game gameDetails) throws GameNotFoundException {

        Game oldGame = this.gameRepository.findById(gameId)
                .orElseThrow(() -> new GameNotFoundException(gameId));

        oldGame.setPlayer(gameDetails.getPlayer());
        oldGame.setStatus(gameDetails.getStatus());

        //cart
        // card.setAuthor_name(bookDetails.getAuthor_name());
        // card.setIsbn(bookDetails.getIsbn());

        Game updatedGame = gameRepository.save(oldGame);

        return updatedGame;
    }

    // Delete a Note
    @DeleteMapping("/game/{id}")
    public ResponseEntity<?> deleteGame(@PathVariable(value = "id") Long gameId) throws GameNotFoundException {
        Game game = this.gameRepository.findById(gameId)
                .orElseThrow(() -> new GameNotFoundException(gameId));

        this.gameRepository.delete(game);

        return ResponseEntity.ok().build();
    }
}