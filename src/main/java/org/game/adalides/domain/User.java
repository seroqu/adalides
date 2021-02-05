package org.game.adalides.domain;

import java.util.List;
/**
 * Esta es la clase usuario
 *
 *
 * */
public class User {

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

    public List<GamesClass> getMyCards() {
        return myCards;
    }

    public void setMyCards(List<GamesClass> myCards) {
        this.myCards = myCards;
    }

    public int getGameInSeries() {
        return gameInSeries;
    }

    public void setGameInSeries(int gameInSeries) {
        this.gameInSeries = gameInSeries;
    }

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

    private String alias;
    private int life;
    private List<GamesClass> myCards;
    private int gameInSeries;
    private int myEter;
    private int level;
    private int spaces;
    private int myMap;




}
