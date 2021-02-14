package org.game.adalides.domain;

import javax.persistence.*;
import javax.validation.constraints.NotBlank;

@Entity
@Table(name = "card")
public class CardElement {

    @Id
    @GeneratedValue
    @Column(name = "id_card")
    private Long id;

    @NotBlank
    private String name;

    private short level;
    private short price;
    @NotBlank
    private short attack;
    private short defense;

    private String description;

    //  private String element;
    //  private String status;


    /*   public String getStatus() {
           return status;
       }

       public void setStatus(String status) {
           this.status = status;
       }
   */
    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }


    public short getAttack() {
        return attack;
    }

    public void setAttack(short attack) {
        this.attack = attack;
    }

    public short getDefense() {
        return defense;
    }

    public void setDefense(short defense) {
        this.defense = defense;
    }

    public short getLevel() {
        return level;
    }

    public void setLevel(short level) {
        this.level = level;
    }


    public short getPrice() {
        return price;
    }

    public void setPrice(short price) {
        this.price = price;
    }

 /*   public String getElement() {
        return element;
    }

    public void setElement(String element) {
        this.element = element;
    }
*/


}
