package org.game.adalides.utils;

import org.game.adalides.domain.User;

import java.util.ArrayList;
import java.util.List;

//Starting all the cards in new Game
public class Inicializator {


    final String elements[] = {"fire","electric","ground","air","ice","wild","robot","demon","angel","protector","asesins","mage"};
    private  List<User> usersInGame;
    Inicializator(int numberOfPlayes){

        usersInGame = new ArrayList<>(numberOfPlayes);

        for (int i = 0; i < numberOfPlayes; i++) {
            User user2 = new User();
            User user = new User();
            user.setAlias("Jugador " + (i + 1));
            user.setGameInSeries(0);
            user.setMyEter(20);
            user.setLife(30);
            user.setSpaces(0);
            user.setMyMap(3);
            user.setLevel(1);

            usersInGame.add(user);

        }






    }








}
