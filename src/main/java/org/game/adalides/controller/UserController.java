package org.game.adalides.controller;

import org.game.adalides.domain.CardElement;
import org.game.adalides.domain.User;
import org.game.adalides.exception.UserNotFoundException;
import org.game.adalides.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;
import java.util.List;

@RestController
public class UserController {

    @Autowired
    UserRepository user;

    // Get All Notes
    @GetMapping("/users")
    public List<User> getAllUser() {
        return user.findAll();
    }

    // Create a new User
    @PostMapping("/users")
    public User createUser(@Valid @RequestBody User user) {
        return this.user.save(user);
    }

    // Get a normal User
    @GetMapping("/users/{id}")
    public User getUserById(@PathVariable(value = "id") Long userId) throws UserNotFoundException {
        return user.findById(userId)
                .orElseThrow(() -> new UserNotFoundException(userId));
    }

    // Update a Note
    @PutMapping("/users/{id}")
    public User updateUser(@PathVariable(value = "id") Long userId,
                                  @Valid @RequestBody User userDetails) throws UserNotFoundException {

        User oldUser = this.user.findById(userId)
                .orElseThrow(() -> new UserNotFoundException(userId));

        oldUser.setAlias(userDetails.getAlias());
        oldUser.setRacha(userDetails.getRacha());
        oldUser.setLife(userDetails.getLife());
        //cart
        // card.setAuthor_name(bookDetails.getAuthor_name());
        // card.setIsbn(bookDetails.getIsbn());

        User updateUser = user.save(oldUser);

        return updateUser;
    }

    // Delete a Note
    @DeleteMapping("/users/{id}")
    public ResponseEntity<?> deleteUser(@PathVariable(value = "id") Long cardId) throws UserNotFoundException {
        User user = this.user.findById(cardId)
                .orElseThrow(() -> new UserNotFoundException(cardId));

        this.user.delete(user);

        return ResponseEntity.ok().build();
    }
}
