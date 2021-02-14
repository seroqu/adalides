package org.game.adalides.domain;

import javax.persistence.*;
import java.util.List;
import javax.validation.constraints.NotBlank;

@Entity
@Table(name = "user")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_user")
    private Long id;

    @Column(name = "username")
    private String alias;
    @Column(name="health")
    private int life;

    //private List<GamesClass> myCards;

    //private int gameInSeries;
    @Column(name = "money")
    private int myEter;

    private int level;

    @Column(name = "board_spaces")
    private int spaces;

    @Column(name = "maps_spaces")
    private int myMap;


    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public int getRacha() {
        return racha;
    }

    public void setRacha(int racha) {
        this.racha = racha;
    }

    private int racha;
    public String getAlias() {
        return alias;
    }
    public void setAlias(String alias) {
        this.alias = alias;
    }
    public int getLife() {
        return life;
    }
    public void setLife(int life) {
        this.life = life;
    }

    //public List<GamesClass> getMyCards() {
     //   return myCards;
   // }

   // public void setMyCards(List<GamesClass> myCards) {
     //   this.myCards = myCards;
   // }

   /* public int getGameInSeries() {
        return gameInSeries;
    }

    public void setGameInSeries(int gameInSeries) {
        this.gameInSeries = gameInSeries;
    }*/

    public int getMyEter() {
        return myEter;
    }
    public void setMyEter(int myEter) {
        this.myEter = myEter;
    }
    public int getLevel() {
        return level;
    }
    public void setLevel(int level) {
        this.level = level;
    }
    public int getSpaces() {
        return spaces;
    }
    public void setSpaces(int spaces) {
        this.spaces = spaces;
    }
    public int getMyMap() {
        return myMap;
    }
    public void setMyMap(int myMap) {
        this.myMap = myMap;
    }

}
