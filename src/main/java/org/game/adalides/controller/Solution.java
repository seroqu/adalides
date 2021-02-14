package org.game.adalides.controller;
import java.io.*;
import java.util.*;
import java.text.*;
import java.math.*;
import java.util.regex.*;
import java.lang.reflect.*;

class Prime {
    void checkPrime(Integer... numbers) {

        String result = "";
        List<Integer> myList = Arrays.asList(numbers);
        int counter = 0;

        for (Integer item : myList) {

            if (item == 2) {
                result = result.equals("") ? item.toString() : result + " " + 2;
            } else if (item == 1 || item % 2 == 0) {
                continue;
            } else {
                for (int j = 3; j < item; j += 2) {
                    if (item % j == 0) {
                        result = result.equals("") ? item.toString() : result + " " + item;
                        break;
                    }
                }
            }
            System.out.println(result);
        }
    }
}

public class Solution {
    static InputStream in;

    public static void main(String[] args) {
        try {
            BufferedReader br = new BufferedReader(new InputStreamReader(in));
            int n1 = Integer.parseInt(br.readLine());
            int n2 = Integer.parseInt(br.readLine());
            int n3 = Integer.parseInt(br.readLine());
            int n4 = Integer.parseInt(br.readLine());
            int n5 = Integer.parseInt(br.readLine());
            Prime ob = new Prime();
            ob.checkPrime(n1);
            ob.checkPrime(n1, n2);
            ob.checkPrime(n1, n2, n3);
            ob.checkPrime(n1, n2, n3, n4, n5);
            Method[] methods = Prime.class.getDeclaredMethods();
            Set<String> set = new HashSet<>();
            boolean overload = false;
            for (int i = 0; i < methods.length; i++) {
                if (set.contains(methods[i].getName())) {
                    overload = true;
                    break;
                }
                set.add(methods[i].getName());

            }
            if (overload) {
                throw new Exception("Overloading not allowed");
            }
        } catch (Exception e) {
            System.out.println(e);
        }
    }

}

class MyCalculator {

    void add(Integer... myNumbers) {
        String result = "";
        List<Integer> myList = Arrays.asList(myNumbers);
        int counter = 0;

        for (Integer item : myList) {
            counter = counter + item;
            result = result.equals("") ? item.toString() : result + " + " + item;
        }
        System.out.println(result + " = " + counter);
    }

    long power(int number, int p) throws Exception {

        if (number < 0 || p < 0) {
            throw new Exception("n or p should not be negative.");
        } else if (number == 0 || p == 0) {
            throw new Exception("n and p should not be zero");
        }
        long result = (long) Math.pow(number, p);
        return result;
    }
}

