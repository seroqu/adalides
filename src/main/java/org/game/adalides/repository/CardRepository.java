package org.game.adalides.repository;
import org.game.adalides.domain.CardElement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
@Repository
public interface CardRepository  extends JpaRepository<CardElement, Long> {

}



